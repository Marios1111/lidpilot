#!/usr/bin/env ruby
# frozen_string_literal: true

require "base64"
require "digest"
require "fileutils"
require "json"
require "net/http"
require "open3"
require "openssl"
require "optparse"
require "pathname"
require "rexml/document"
require "tmpdir"
require "uri"

class ValidationError < StandardError; end

ROOT = Pathname(__dir__).parent
DEFAULTS_PATH = ROOT.join("Config", "ReleaseDefaults.json")
DEFAULT_BRANDED_RC_FEED = "https://lidpilot.app/rc/appcast.xml"
LEGACY_RC_FEED = "https://marios1111.github.io/lidpilot/rc/appcast.xml"
STABLE_FEED = "https://lidpilot.app/updates/appcast.xml"
SPARKLE_NAMESPACE = "http://www.andymatuschak.org/xml-namespaces/sparkle"
MAX_PUBLIC_ASSET_BYTES = 256 * 1024 * 1024
MAX_PUBLIC_TOTAL_BYTES = 512 * 1024 * 1024
MAX_PUBLIC_RESPONSE_BYTES = 1024 * 1024
MAX_SIGNED_METADATA_BYTES = 4 * 1024 * 1024
MAX_PUBLIC_REDIRECTS = 3
MAX_PUBLIC_ASSET_SECONDS = 60
MAX_STABLE_ABSENCE_SECONDS = 30
PUBLIC_ASSET_HOSTS = %w[github.com release-assets.githubusercontent.com objects.githubusercontent.com].freeze
LEGACY_RC_LABEL = "1.0.0-rc.4"
LEGACY_RC_APPCAST_SHA256 = "6722017a74a3aaae46d7ab4452cc4bce98deefbcef54d2084057b37ae464423e"
LEGACY_RC_NOTES_SHA256 = "cb86894e9fc3769c43adc59b67f76c9ae6e9665526650456c91098ef5f568436"
SPKI_ED25519_PREFIX = ["302a300506032b6570032100"].pack("H*")
SIGNATURE_BLOCK = /<!--\s*sparkle-signatures:\s*edSignature:\s*([A-Za-z0-9+\/=]+)\s*length:\s*(\d+)\s*-->/n
POST_SIGNATURE_WARNING = <<~COMMENT.strip
  <!-- sparkle-sign-warning:
  IMPORTANT: This file was signed by Sparkle. Any modifications to this file requires updating signatures in appcasts that reference this file! This will involve re-running generate_appcast or sign_update.
  -->
COMMENT
OPENSSL3_PATH_ENV = "LIDPILOT_OPENSSL3"
OPENSSL3_FIXED_PATHS = [
  "/opt/homebrew/opt/openssl@3/bin/openssl",
  "/usr/local/opt/openssl@3/bin/openssl"
].freeze

def fail_validation(message)
  raise ValidationError, message
end

def validate_openssl3_executable(path)
  fail_validation("OpenSSL 3 executable path must be absolute") unless Pathname.new(path).absolute?
  fail_validation("OpenSSL 3 executable is missing or not executable: #{path}") unless File.file?(path) && File.executable?(path)

  stdout, stderr, status = Open3.capture3(path, "version")
  version = [stdout, stderr].map(&:strip).reject(&:empty?).join(" ")
  unless status.success? && stdout.match?(/\AOpenSSL 3(?:\.|\s)/)
    fail_validation("OpenSSL 3 is required; #{path} reported #{version.empty? ? "an unknown version" : version}")
  end

  path
rescue Errno::ENOENT, Errno::EACCES => e
  fail_validation("OpenSSL 3 executable could not be run at #{path}: #{e.message}")
end

def openssl3_executable(path_environment: ENV.fetch("PATH", ""), explicit_path: ENV[OPENSSL3_PATH_ENV])
  unless explicit_path.to_s.empty?
    return validate_openssl3_executable(explicit_path)
  end

  path_candidates = path_environment.split(File::PATH_SEPARATOR)
                                   .select { |directory| Pathname.new(directory).absolute? }
                                   .map { |directory| File.join(directory, "openssl") }
  (OPENSSL3_FIXED_PATHS + path_candidates).uniq.each do |candidate|
    next unless File.file?(candidate) && File.executable?(candidate)

    begin
      return validate_openssl3_executable(candidate)
    rescue ValidationError
      # LibreSSL and other OpenSSL versions do not meet the Ed25519 verifier requirement.
    end
  end

  fail_validation("OpenSSL 3 is required to verify signed Pages metadata. Set #{OPENSSL3_PATH_ENV} to an existing OpenSSL 3 executable.")
end

def require_file(path, label)
  fail_validation("#{label} is missing: #{path}") unless File.file?(path)
  fail_validation("#{label} must not be a symlink: #{path}") if File.symlink?(path)
end

def require_directory(path, label)
  fail_validation("#{label} is missing: #{path}") unless File.directory?(path)
  fail_validation("#{label} must not be a symlink: #{path}") if File.symlink?(path)
end

def child_named(element, name)
  element&.each_element do |child|
    return child if child.name.split(":").last == name

    found = child_named(child, name)
    return found if found
  end
  nil
end

def child_text(element, name)
  child = child_named(element, name)
  child ? child.texts.map(&:value).join.strip : nil
end

def attribute_named(element, name)
  element&.attributes&.each_attribute do |attribute|
    return attribute.value if attribute.expanded_name.split(":").last == name
  end
  nil
end

def one_direct_element(parent, name, namespace, label)
  matches = parent ? parent.elements.to_a.select { |element| element.name == name } : []
  fail_validation("stable appcast must contain exactly one #{label}") unless matches.length == 1

  element = matches.first
  fail_validation("stable appcast #{label} must use the expected XML namespace") unless element.namespace.to_s == namespace

  element
end

def namespaced_attribute_named(element, name, namespace, label)
  matches = element ? element.attributes.to_a.select { |attribute| attribute.name == name } : []
  fail_validation("stable appcast #{label} is missing or duplicated") unless matches.length == 1

  attribute = matches.first
  fail_validation("stable appcast #{label} must use the expected XML namespace") unless attribute.namespace.to_s == namespace

  attribute.value
end

def unqualified_attribute_named(element, name, label)
  namespaced_attribute_named(element, name, "", label)
end

def decode_signature(value, label)
  signature = Base64.strict_decode64(value.to_s)
  fail_validation("#{label} must be a 64-byte Ed25519 signature") unless signature.bytesize == 64

  signature
rescue ArgumentError
  fail_validation("#{label} is not valid Base64")
end

def verify_ed25519(public_key, signature, message, label)
  public_bytes = Base64.strict_decode64(public_key)
  fail_validation("configured Sparkle public key must decode to 32 bytes") unless public_bytes.bytesize == 32

  Dir.mktmpdir("lidpilot-pages-signature-") do |dir|
    public_path = File.join(dir, "public-key.der")
    signature_path = File.join(dir, "signature.bin")
    message_path = File.join(dir, "message.bin")
    File.binwrite(public_path, SPKI_ED25519_PREFIX + public_bytes)
    File.binwrite(signature_path, signature)
    File.binwrite(message_path, message)
    _stdout, stderr, status = Open3.capture3(
      openssl3_executable, "pkeyutl", "-verify", "-pubin", "-keyform", "DER", "-inkey", public_path,
      "-sigfile", signature_path, "-rawin", "-in", message_path
    )
    fail_validation("#{label} Ed25519 signature verification failed#{stderr.strip.empty? ? "" : ": #{stderr.strip}"}") unless status.success?
  end
rescue Errno::ENOENT
  fail_validation("OpenSSL 3 became unavailable while verifying signed Pages metadata")
rescue ArgumentError
  fail_validation("configured Sparkle public key is not valid Base64")
end

def validate_feed_signature(raw, public_key, channel: "RC")
  match = SIGNATURE_BLOCK.match(raw)
  fail_validation("#{channel} appcast must contain exactly one Sparkle feed signature block") unless match && raw.scan(SIGNATURE_BLOCK).length == 1
  signed_length = Integer(match[2], 10)
  fail_validation("#{channel} appcast signed-byte length does not match the signature block offset") unless signed_length == match.begin(0)
  trailer = raw.byteslice(match.end(0), raw.bytesize - match.end(0)).to_s.strip
  unless trailer.empty? || trailer == POST_SIGNATURE_WARNING
    fail_validation("#{channel} appcast has bytes outside its signature block other than Sparkle's known warning comment")
  end

  signature = decode_signature(match[1], "#{channel} appcast feed signature")
  signed_bytes = raw.byteslice(0, match.begin(0))
  verify_ed25519(public_key, signature, signed_bytes, "#{channel} appcast feed")
end

def validate_rc_feed_url(value)
  return :legacy if value == LEGACY_RC_FEED
  return :branded if value == DEFAULT_BRANDED_RC_FEED

  fail_validation("RC appcast link must use the exact branded RC URL or the explicitly preserved legacy RC URL")
end

def validate_stable_manifest(site_root, defaults)
  updates_path = site_root.join("updates")
  require_directory(updates_path, "stable website directory")
  manifest_path = updates_path.join("manifest.json")
  require_file(manifest_path, "stable release manifest")
  fail_validation("stable release manifest exceeds its size limit") if File.size(manifest_path) > MAX_PUBLIC_RESPONSE_BYTES
  raw_manifest = File.binread(manifest_path)
  fail_validation("stable release manifest is empty or too large") if raw_manifest.empty? || raw_manifest.bytesize > MAX_PUBLIC_RESPONSE_BYTES
  manifest = JSON.parse(raw_manifest)

  expected_keys = %w[version releaseLabel channel hardwareValidation profilingEnabled build feedURL downloadURL files].sort
  fail_validation("stable release manifest has an unexpected schema") unless manifest.is_a?(Hash) && manifest.keys.sort == expected_keys
  version = manifest.fetch("version")
  fail_validation("stable release manifest version must be numeric x.y.z") unless version.is_a?(String) && version.match?(/\A[0-9]+\.[0-9]+\.[0-9]+\z/)
  fail_validation("stable release label must equal its numeric version") unless manifest.fetch("releaseLabel") == version
  fail_validation("stable release manifest channel must be stable") unless manifest.fetch("channel") == "stable"
  fail_validation("stable release manifest hardware validation must be approved") unless manifest.fetch("hardwareValidation") == "approved"
  fail_validation("stable release manifest must not enable profiling") unless manifest.fetch("profilingEnabled") == false
  build = manifest.fetch("build")
  fail_validation("stable release build must be a positive integer") unless build.is_a?(String) && build.match?(/\A[1-9][0-9]*\z/)
  fail_validation("stable release manifest feed URL must be canonical") unless manifest.fetch("feedURL") == defaults.fetch("stableFeedURL") && manifest.fetch("feedURL") == STABLE_FEED
  repository = defaults.fetch("repository")
  fail_validation("release defaults repository is invalid") unless repository.match?(/\A[A-Za-z0-9-]+\/[A-Za-z0-9_.-]+\z/)
  expected_download = "https://github.com/#{repository}/releases/download/v#{version}/LidPilot-#{version}.zip"
  fail_validation("stable release download URL must identify its immutable GitHub Release asset") unless manifest.fetch("downloadURL") == expected_download

  expected_files = {
    "dmg" => "LidPilot-#{version}.dmg",
    "update-archive" => "LidPilot-#{version}.zip",
    "appcast" => "appcast.xml",
    "release-notes" => "LidPilot-#{version}.md"
  }
  files = manifest.fetch("files")
  fail_validation("stable release manifest must contain exactly the four release artifacts") unless files.is_a?(Array) && files.length == expected_files.length
  seen = {}
  files.each do |entry|
    fail_validation("stable release manifest file entry has an unexpected schema") unless entry.is_a?(Hash) && entry.keys.sort == %w[name path sha256]
    name = entry.fetch("name")
    path = entry.fetch("path")
    digest = entry.fetch("sha256")
    fail_validation("stable release manifest has a duplicate or unknown artifact") unless expected_files.key?(name) && !seen.key?(name)
    fail_validation("stable release artifact path does not match its immutable filename") unless path == expected_files.fetch(name)
    fail_validation("stable release artifact SHA-256 must be 64 lowercase hexadecimal characters") unless digest.is_a?(String) && digest.match?(/\A[a-f0-9]{64}\z/)
    seen[name] = entry
  end
  fail_validation("stable release manifest is missing an artifact") unless seen.keys.sort == expected_files.keys.sort

  { path: manifest_path, raw: raw_manifest, values: manifest, files: seen }
rescue JSON::ParserError => e
  fail_validation("stable release manifest is malformed JSON: #{e.message}")
rescue KeyError => e
  fail_validation("stable release manifest is missing #{e.key}")
end

def validate_stable_site(site_root, defaults)
  manifest_info = validate_stable_manifest(site_root, defaults)
  manifest = manifest_info.fetch(:values)
  updates_path = site_root.join("updates")
  appcast_path = updates_path.join("appcast.xml")
  notes_path = updates_path.join("LidPilot-#{manifest.fetch("releaseLabel")}.md")
  require_file(appcast_path, "stable appcast")
  require_file(notes_path, "signed stable release notes")
  expected_entries = ["appcast.xml", "manifest.json", "LidPilot-#{manifest.fetch("releaseLabel")}.md"].sort
  fail_validation("stable website directory contains unexpected files") unless updates_path.children.map(&:basename).map(&:to_s).sort == expected_entries
  fail_validation("stable appcast or release notes exceeds its metadata size limit") if File.size(appcast_path) > MAX_SIGNED_METADATA_BYTES || File.size(notes_path) > MAX_SIGNED_METADATA_BYTES
  appcast_bytes = File.binread(appcast_path)
  notes_bytes = File.binread(notes_path)
  fail_validation("stable appcast hash does not match the release manifest") unless Digest::SHA256.hexdigest(appcast_bytes) == manifest_info.fetch(:files).fetch("appcast").fetch("sha256")
  fail_validation("stable release-notes hash does not match the release manifest") unless Digest::SHA256.hexdigest(notes_bytes) == manifest_info.fetch(:files).fetch("release-notes").fetch("sha256")
  fail_validation("stable appcast is empty or not valid UTF-8 XML") if appcast_bytes.empty? || !appcast_bytes.dup.force_encoding(Encoding::UTF_8).valid_encoding?
  validate_feed_signature(appcast_bytes, defaults.fetch("sparklePublicKey"), channel: "stable")

  document = REXML::Document.new(appcast_bytes.dup.force_encoding(Encoding::UTF_8))
  fail_validation("stable appcast root must be unqualified rss") unless document.root&.name == "rss" && document.root.namespace.to_s.empty?
  channel = one_direct_element(document.root, "channel", "", "RSS channel")
  item = one_direct_element(channel, "item", "", "RSS update item")
  link = one_direct_element(item, "link", "", "RSS update link")
  fail_validation("stable appcast link must use the canonical stable feed URL") unless link.texts.map(&:value).join.strip == STABLE_FEED
  release_notes = one_direct_element(item, "releaseNotesLink", SPARKLE_NAMESPACE, "Sparkle release-notes link")
  version = one_direct_element(item, "version", SPARKLE_NAMESPACE, "Sparkle build version")
  short_version = one_direct_element(item, "shortVersionString", SPARKLE_NAMESPACE, "Sparkle short version")
  minimum_system_version = one_direct_element(item, "minimumSystemVersion", SPARKLE_NAMESPACE, "Sparkle minimum system version")
  hardware_requirements = one_direct_element(item, "hardwareRequirements", SPARKLE_NAMESPACE, "Sparkle hardware requirements")
  enclosure = one_direct_element(item, "enclosure", "", "RSS enclosure")
  notes_url = release_notes.texts.map(&:value).join.strip
  expected_notes_url = "https://lidpilot.app/updates/LidPilot-#{manifest.fetch("releaseLabel")}.md"
  fail_validation("stable release-notes URL must use the branded stable path") unless notes_url == expected_notes_url
  notes_signature = decode_signature(namespaced_attribute_named(release_notes, "edSignature", SPARKLE_NAMESPACE, "Sparkle release-notes signature"), "stable release-notes signature")
  verify_ed25519(defaults.fetch("sparklePublicKey"), notes_signature, notes_bytes, "stable release notes")
  fail_validation("stable release-notes length does not match the file") unless namespaced_attribute_named(release_notes, "length", SPARKLE_NAMESPACE, "Sparkle release-notes length") == notes_bytes.bytesize.to_s

  fail_validation("stable appcast short version does not match its release manifest") unless short_version.texts.map(&:value).join.strip == manifest.fetch("version")
  fail_validation("stable appcast build does not match its release manifest") unless version.texts.map(&:value).join.strip == manifest.fetch("build")
  fail_validation("stable appcast minimum system version must remain 15.0") unless minimum_system_version.texts.map(&:value).join.strip == "15.0"
  fail_validation("stable appcast hardware requirement must remain arm64") unless hardware_requirements.texts.map(&:value).join.strip == "arm64"
  fail_validation("stable archive URL must match the immutable release manifest URL") unless unqualified_attribute_named(enclosure, "url", "RSS enclosure URL") == manifest.fetch("downloadURL")
  archive_length = unqualified_attribute_named(enclosure, "length", "RSS enclosure length")
  fail_validation("stable archive length must be a positive byte count") unless archive_length.match?(/\A[1-9][0-9]*\z/)
  archive_signature = decode_signature(namespaced_attribute_named(enclosure, "edSignature", SPARKLE_NAMESPACE, "Sparkle archive signature"), "stable archive signature")

  {
    manifest: manifest_info,
    item: item,
    archive_signature: archive_signature,
    archive_length: Integer(archive_length, 10),
    appcast_path: appcast_path,
    notes_path: notes_path
  }
rescue REXML::ParseException => e
  fail_validation("stable appcast XML is malformed: #{e.message}")
rescue KeyError => e
  fail_validation("release defaults are missing #{e.key}")
end

def validate_public_asset_uri(uri, initial: false)
  fail_validation("public release asset URL must use HTTPS on port 443") unless uri.is_a?(URI::HTTPS) && uri.port == 443
  fail_validation("public release asset URL must not contain credentials or fragments") unless uri.userinfo.nil? && uri.fragment.nil?
  allowed_hosts = initial ? ["github.com"] : PUBLIC_ASSET_HOSTS
  fail_validation("public release asset redirected to an unapproved host") unless allowed_hosts.include?(uri.host.to_s.downcase)
  uri
end

def public_release_asset_url(repository, release_label, filename)
  URI("https://github.com/#{repository}/releases/download/v#{release_label}/#{filename}")
end

def download_public_release_asset(url, destination, max_bytes: MAX_PUBLIC_ASSET_BYTES)
  uri = validate_public_asset_uri(URI(url.to_s), initial: true)
  redirects = 0
  deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + MAX_PUBLIC_ASSET_SECONDS
  loop do
    fail_validation("public release asset request timed out") if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
    validate_public_asset_uri(uri, initial: redirects.zero?)
    http = Net::HTTP.new(uri.host, uri.port, nil)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_PEER
    http.open_timeout = 5
    http.read_timeout = 10
    request = Net::HTTP::Get.new(uri.request_uri)
    request["Accept-Encoding"] = "identity"
    request["User-Agent"] = "LidPilot-Pages-Validator"
    redirected_uri = nil
    downloaded_bytes = nil

    http.start do |client|
      client.request(request) do |response|
        if response.is_a?(Net::HTTPRedirection)
          fail_validation("public release asset exceeded the redirect limit") if redirects >= MAX_PUBLIC_REDIRECTS
          location = response["location"]
          fail_validation("public release asset redirect is missing a location") if location.to_s.empty?
          redirected_uri = validate_public_asset_uri(URI.join(uri.to_s, location), initial: false)
          response_bytes = 0
          response.read_body do |chunk|
            fail_validation("public release asset request timed out") if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
            response_bytes += chunk.bytesize
            fail_validation("public release asset redirect response exceeded its size limit") if response_bytes > MAX_PUBLIC_RESPONSE_BYTES
          end
        elsif response.code == "200"
          content_length = response["content-length"]
          if content_length && (!content_length.match?(/\A[0-9]+\z/) || Integer(content_length, 10) > max_bytes)
            fail_validation("public release asset exceeds its size limit")
          end
          downloaded_bytes = 0
          File.open(destination, "wb") do |file|
            response.read_body do |chunk|
              fail_validation("public release asset request timed out") if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
              downloaded_bytes += chunk.bytesize
              fail_validation("public release asset exceeds its size limit") if downloaded_bytes > max_bytes
              file.write(chunk)
            end
          end
        else
          fail_validation("public release asset request returned HTTP #{response.code}")
        end
      end
    end

    if redirected_uri
      uri = redirected_uri
      redirects += 1
    else
      fail_validation("public release asset response was empty") if downloaded_bytes.nil? || downloaded_bytes.zero?
      return downloaded_bytes
    end
  end
rescue ValidationError
  raise
rescue StandardError => e
  fail_validation("public release asset could not be fetched safely (#{e.class})")
end

def verify_public_release_assets(site_root, defaults, stable_info, downloader: method(:download_public_release_asset))
  manifest_info = stable_info.fetch(:manifest)
  manifest = manifest_info.fetch(:values)
  repository = defaults.fetch("repository")
  files = manifest_info.fetch(:files)
  Dir.mktmpdir("lidpilot-public-release-assets-") do |dir|
    total_bytes = 0
    fetch = lambda do |url, destination, limit|
      remaining = MAX_PUBLIC_TOTAL_BYTES - total_bytes
      fail_validation("public release assets exceeded their aggregate size limit") if remaining <= 0
      size = downloader.call(url, destination, max_bytes: [limit, remaining].min)
      actual_size = File.size(destination)
      fail_validation("public release asset downloader returned an inconsistent byte count") unless size == actual_size && actual_size <= [limit, remaining].min
      total_bytes += size
      size
    end
    manifest_asset = public_release_asset_url(repository, manifest.fetch("releaseLabel"), "manifest.json")
    downloaded_manifest = File.join(dir, "manifest.json")
    fetch.call(manifest_asset, downloaded_manifest, MAX_PUBLIC_RESPONSE_BYTES)
    fail_validation("public stable release manifest differs from the committed manifest") unless File.binread(downloaded_manifest) == manifest_info.fetch(:raw)

    downloaded = {}
    files.each do |name, entry|
      url = public_release_asset_url(repository, manifest.fetch("releaseLabel"), entry.fetch("path"))
      destination = File.join(dir, entry.fetch("path"))
      fetch.call(url, destination, MAX_PUBLIC_ASSET_BYTES)
      actual_digest = Digest::SHA256.file(destination).hexdigest
      fail_validation("public #{name} bytes do not match the release manifest SHA-256") unless actual_digest == entry.fetch("sha256")
      downloaded[name] = destination
    end

    fail_validation("public stable archive length does not match the signed appcast") unless File.size(downloaded.fetch("update-archive")) == stable_info.fetch(:archive_length)
    verify_ed25519(
      defaults.fetch("sparklePublicKey"),
      stable_info.fetch(:archive_signature),
      File.binread(downloaded.fetch("update-archive")),
      "public stable update archive"
    )
  end
  "verified public stable release bytes and signatures"
end

def require_stable_feed_absent
  uri = URI(STABLE_FEED)
  fail_validation("stable-feed absence check URL is not the exact canonical HTTPS endpoint") unless uri.is_a?(URI::HTTPS) && uri.to_s == STABLE_FEED && uri.port == 443 && uri.userinfo.nil?
  deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + MAX_STABLE_ABSENCE_SECONDS
  http = Net::HTTP.new(uri.host, uri.port, nil)
  http.use_ssl = true
  http.verify_mode = OpenSSL::SSL::VERIFY_PEER
  http.open_timeout = 5
  http.read_timeout = 10
  request = Net::HTTP::Get.new(uri.request_uri)
  request["Accept-Encoding"] = "identity"
  request["User-Agent"] = "LidPilot-Pages-Validator"
  status = nil
  http.start do |client|
    client.request(request) do |response|
      status = response.code.to_i
      response_bytes = 0
      response.read_body do |chunk|
        fail_validation("stable-feed absence check request timed out; refusing RC publication") if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
        response_bytes += chunk.bytesize
        fail_validation("stable-feed absence check response exceeded its size limit") if response_bytes > MAX_PUBLIC_RESPONSE_BYTES
      end
    end
  end
  fail_validation("stable-feed absence check request timed out; refusing RC publication") if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
  validate_stable_feed_absence_status(status)

  "confirmed the stable feed endpoint is absent (HTTP #{status})"
rescue ValidationError
  raise
rescue StandardError => e
  fail_validation("could not confirm stable-feed absence (#{e.class}); refusing RC publication")
end

def validate_stable_feed_absence_status(status)
  fail_validation("stable feed is live or its state is ambiguous (HTTP #{status}); refusing RC publication") unless [404, 410].include?(Integer(status))
  status
end

def validate_pages_site(site_root, defaults, publication: :rc, verify_public_assets: false, require_stable_absent: false, downloader: method(:download_public_release_asset))
  site_root = Pathname(site_root)
  require_directory(site_root, "website directory")
  cname_path = site_root.join("CNAME")
  require_file(cname_path, "GitHub Pages CNAME")
  fail_validation("GitHub Pages CNAME must contain exactly lidpilot.app and one newline") unless File.binread(cname_path) == "lidpilot.app\n"

  index_path = site_root.join("index.html")
  require_file(index_path, "website index")
  fail_validation("website index must not be empty") if File.size(index_path).zero?

  fail_validation("release defaults must keep the canonical stable feed URL") unless defaults.fetch("stableFeedURL") == STABLE_FEED
  fail_validation("release defaults must use the branded RC feed URL for new RCs") unless defaults.fetch("rcFeedURL") == DEFAULT_BRANDED_RC_FEED
  fail_validation("website root must not contain an appcast") if [site_root.join("appcast.xml")].any? { |path| File.exist?(path) || File.symlink?(path) }
  fail_validation("Pages publication must be rc or stable") unless %i[rc stable].include?(publication)
  fail_validation("public asset verification is valid only for stable publication") if verify_public_assets && publication != :stable
  fail_validation("stable-feed absence guard is valid only for RC publication") if require_stable_absent && publication != :rc
  fail_validation("stable publication requires public release asset verification") if publication == :stable && !verify_public_assets

  appcast_path = site_root.join("rc", "appcast.xml")
  require_directory(site_root.join("rc"), "RC website directory")
  require_file(appcast_path, "committed RC appcast")
  raw = File.binread(appcast_path)
  fail_validation("committed RC appcast is empty") if raw.empty?
  fail_validation("committed RC appcast is not valid UTF-8 XML") unless raw.dup.force_encoding(Encoding::UTF_8).valid_encoding?
  validate_feed_signature(raw, defaults.fetch("sparklePublicKey"))

  document = REXML::Document.new(raw.dup.force_encoding(Encoding::UTF_8))
  fail_validation("RC appcast root must be rss") unless document.root&.name == "rss"
  item = child_named(document.root, "item")
  fail_validation("RC appcast has no update item") unless item
  feed_url = child_text(item, "link")
  feed_kind = validate_rc_feed_url(feed_url)
  release_notes = child_named(item, "releaseNotesLink")
  enclosure = child_named(item, "enclosure")
  fail_validation("RC appcast is missing signed release notes or archive metadata") unless release_notes && enclosure

  notes_url = child_text(item, "releaseNotesLink")
  label_match = notes_url.to_s.match(%r{\Ahttps://(?:marios1111\.github\.io/lidpilot|lidpilot\.app)/rc/LidPilot-(\d+\.\d+\.\d+-rc\.[1-9][0-9]*)\.md\z})
  fail_validation("RC release-notes URL must use a versioned file under the exact RC path") unless label_match
  release_label = label_match[1]
  version = release_label.sub(/-rc\.[1-9][0-9]*\z/, "")
  expected_feed = feed_kind == :legacy ? LEGACY_RC_FEED : DEFAULT_BRANDED_RC_FEED
  expected_notes = "#{expected_feed.delete_suffix("appcast.xml")}LidPilot-#{release_label}.md"
  fail_validation("RC release-notes URL must match the exact origin and path of its feed") unless notes_url == expected_notes
  if feed_kind == :legacy
    fail_validation("only the byte-identical signed RC4 feed may retain the legacy GitHub Pages URL") unless release_label == LEGACY_RC_LABEL && Digest::SHA256.hexdigest(raw) == LEGACY_RC_APPCAST_SHA256
  end

  notes_filename = "LidPilot-#{release_label}.md"
  notes_path = site_root.join("rc", notes_filename)
  require_file(notes_path, "signed RC release notes")
  notes_bytes = File.binread(notes_path)
  notes_signature = decode_signature(attribute_named(release_notes, "edSignature"), "RC release-notes signature")
  verify_ed25519(defaults.fetch("sparklePublicKey"), notes_signature, notes_bytes, "RC release notes")
  if feed_kind == :legacy
    fail_validation("legacy signed RC4 notes must remain byte-identical") unless Digest::SHA256.hexdigest(notes_bytes) == LEGACY_RC_NOTES_SHA256
  end
  fail_validation("signed RC release-notes length does not match the file") unless attribute_named(release_notes, "length").to_s == notes_bytes.bytesize.to_s

  short_version = child_text(item, "shortVersionString")
  build = child_text(item, "version")
  fail_validation("RC appcast short version does not match its release label") unless short_version == version
  fail_validation("RC appcast build must be a positive integer") unless build&.match?(/\A[1-9][0-9]*\z/)
  fail_validation("RC appcast minimum system version must remain 15.0") unless child_text(item, "minimumSystemVersion") == "15.0"
  fail_validation("RC appcast hardware requirement must remain arm64") unless child_text(item, "hardwareRequirements") == "arm64"

  expected_download = "https://github.com/#{defaults.fetch("repository")}/releases/download/v#{release_label}/LidPilot-#{release_label}.zip"
  fail_validation("RC archive URL must exactly identify its immutable GitHub Release asset") unless attribute_named(enclosure, "url") == expected_download
  fail_validation("RC archive length must be a positive byte count") unless attribute_named(enclosure, "length")&.match?(/\A[1-9][0-9]*\z/)
  decode_signature(attribute_named(enclosure, "edSignature"), "RC archive signature")

  result = "validated #{release_label} Pages metadata (#{feed_kind == :legacy ? "preserved legacy" : "branded"} RC feed)"
  if publication == :rc
    updates_path = site_root.join("updates")
    fail_validation("stable website files may not be published by the RC workflow") if File.exist?(updates_path) || File.symlink?(updates_path)
    result = [result, require_stable_feed_absent].join("; ") if require_stable_absent
  else
    stable_info = validate_stable_site(site_root, defaults)
    result = [result, "validated stable feed and manifest"].join("; ")
    result = [result, verify_public_release_assets(site_root, defaults, stable_info, downloader: downloader)].join("; ") if verify_public_assets
  end
  result
rescue REXML::ParseException => e
  fail_validation("RC appcast XML is malformed: #{e.message}")
rescue KeyError => e
  fail_validation("release defaults are missing #{e.key}")
rescue URI::InvalidURIError => e
  fail_validation("RC Pages URL is invalid: #{e.message}")
end

def expect_failure(label, expected: nil)
  rejected = false
  begin
    yield
  rescue ValidationError => e
    fail_validation("Pages validator self-test rejected #{label} for the wrong reason: #{e.message}") if expected && !e.message.include?(expected)
    rejected = true
  end
  fail_validation("Pages validator self-test expected rejection: #{label}") unless rejected

  puts "self-test rejected #{label}"
end

def self_test_openssl_selection
  selected = openssl3_executable(path_environment: "/usr/bin:/bin", explicit_path: nil)
  stdout, = Open3.capture3(selected, "version")
  fail_validation("self-test did not select OpenSSL 3 with a restricted PATH") unless stdout.match?(/\AOpenSSL 3(?:\.|\s)/)
  puts "self-test selected OpenSSL 3 with a restricted PATH"

  Dir.mktmpdir("lidpilot-pages-openssl-") do |dir|
    legacy_executable = File.join(dir, "openssl")
    File.write(legacy_executable, "#!/bin/sh\nprintf '%s\\n' 'LibreSSL 3.3.6'\n")
    FileUtils.chmod(0o700, legacy_executable)
    expect_failure("LibreSSL is not accepted as the OpenSSL 3 verifier") do
      openssl3_executable(path_environment: "/usr/bin:/bin", explicit_path: legacy_executable)
    end
  end
end

def self_test(defaults)
  self_test_openssl_selection
  site = ROOT.join("website")
  validate_stable_site(site, defaults) if site.join("updates").exist?
  fail_validation("self-test did not accept branded RC URL") unless validate_rc_feed_url(DEFAULT_BRANDED_RC_FEED) == :branded
  fail_validation("self-test did not accept the explicit legacy RC URL") unless validate_rc_feed_url(LEGACY_RC_FEED) == :legacy
  expect_failure("legacy stable GitHub Pages URL") { validate_rc_feed_url("https://marios1111.github.io/lidpilot/appcast.xml") }
  expect_failure("unrelated RC origin") { validate_rc_feed_url("https://attacker.example/rc/appcast.xml") }

  Dir.mktmpdir("lidpilot-pages-validator-") do |dir|
    copy = File.join(dir, "website")
    FileUtils.cp_r("#{site}/.", copy)
    # Exercise RC-only publication on its own disposable fixture, even after
    # the committed site gains a stable channel. Keep the production guard intact.
    FileUtils.remove_entry(File.join(copy, "updates")) if File.exist?(File.join(copy, "updates"))
    puts validate_pages_site(copy, defaults)
    valid_feed = Pathname(copy).join("rc", "appcast.xml")
    valid_notes = Pathname(copy).join("rc", "LidPilot-#{LEGACY_RC_LABEL}.md")
    feed_bytes = File.binread(valid_feed)
    notes_bytes = File.binread(valid_notes)

    File.binwrite(valid_feed, feed_bytes.sub("<title>LidPilot</title>", "<title>LidPiloT</title>"))
    expect_failure("tampered signed RC appcast bytes") { validate_pages_site(copy, defaults) }
    File.binwrite(valid_feed, feed_bytes)

    File.binwrite(valid_notes, notes_bytes.sub("RC4", "RCX"))
    expect_failure("tampered signed RC notes bytes") { validate_pages_site(copy, defaults) }
    File.binwrite(valid_notes, notes_bytes)

    File.binwrite(Pathname(copy).join("CNAME"), "other.example\n")
    expect_failure("wrong Pages custom domain") { validate_pages_site(copy, defaults) }
    File.binwrite(Pathname(copy).join("CNAME"), "lidpilot.app\n")

    stable_path = Pathname(copy).join("updates", "appcast.xml")
    FileUtils.mkdir_p(File.dirname(stable_path))
    File.write(stable_path, "<rss/>")
    expect_failure("fabricated stable feed entry") { validate_pages_site(copy, defaults) }

    fixture_root = File.join(dir, "stable-signed-fixture")
    FileUtils.cp_r("#{site}/.", fixture_root)
    fixture_updates = File.join(fixture_root, "updates")
    # This fixture signs its own version. A newer committed release's notes must
    # not leak into the disposable latest-only directory under test.
    FileUtils.remove_entry(fixture_updates) if File.exist?(fixture_updates)
    FileUtils.mkdir_p(fixture_updates)
    key_path = File.join(dir, "fixture-ed25519-private.pem")
    _stdout, stderr, status = Open3.capture3(openssl3_executable, "genpkey", "-algorithm", "ED25519", "-out", key_path)
    fail_validation("self-test could not generate a disposable Ed25519 key: #{stderr}") unless status.success?
    public_der, stderr, status = Open3.capture3(openssl3_executable, "pkey", "-in", key_path, "-pubout", "-outform", "DER")
    fail_validation("self-test could not derive a disposable Ed25519 public key: #{stderr}") unless status.success? && public_der.bytesize >= 32
    fixture_public_key = Base64.strict_encode64(public_der.byteslice(-32, 32))
    sign_fixture = lambda do |bytes, label|
      input_path = File.join(dir, "#{label}.bin")
      File.binwrite(input_path, bytes)
      signature, sign_error, sign_status = Open3.capture3(openssl3_executable, "pkeyutl", "-sign", "-inkey", key_path, "-rawin", "-in", input_path)
      fail_validation("self-test could not sign #{label}: #{sign_error}") unless sign_status.success? && signature.bytesize == 64

      Base64.strict_encode64(signature)
    end

    fixture_version = "1.0.0"
    fixture_label = fixture_version
    fixture_build = "42"
    fixture_notes_name = "LidPilot-#{fixture_label}.md"
    fixture_archive_name = "LidPilot-#{fixture_label}.zip"
    fixture_notes = "LidPilot stable release fixture notes.\n"
    fixture_archive = "disposable stable update archive fixture bytes\n"
    fixture_dmg = "disposable stable DMG fixture bytes\n"
    fixture_download = "https://github.com/#{defaults.fetch("repository")}/releases/download/v#{fixture_label}/#{fixture_archive_name}"
    fixture_notes_signature = sign_fixture.call(fixture_notes, "stable-notes")
    fixture_archive_signature = sign_fixture.call(fixture_archive, "stable-archive")
    base_feed = <<~XML
      <rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle"><channel>
        <item><link>#{STABLE_FEED}</link>
          <sparkle:version>#{fixture_build}</sparkle:version>
          <sparkle:shortVersionString>#{fixture_version}</sparkle:shortVersionString>
          <sparkle:minimumSystemVersion>15.0</sparkle:minimumSystemVersion>
          <sparkle:hardwareRequirements>arm64</sparkle:hardwareRequirements>
          <sparkle:releaseNotesLink sparkle:edSignature="#{fixture_notes_signature}" sparkle:length="#{fixture_notes.bytesize}">#{STABLE_FEED.delete_suffix("appcast.xml")}#{fixture_notes_name}</sparkle:releaseNotesLink>
          <enclosure url="#{fixture_download}" sparkle:edSignature="#{fixture_archive_signature}" length="#{fixture_archive.bytesize}" />
        </item>
      </channel></rss>
    XML
    fixture_feed_signature = sign_fixture.call(base_feed, "stable-appcast")
    fixture_feed = base_feed + "<!-- sparkle-signatures: edSignature: #{fixture_feed_signature} length: #{base_feed.bytesize} -->\n"
    File.binwrite(File.join(fixture_updates, "appcast.xml"), fixture_feed)
    File.binwrite(File.join(fixture_updates, fixture_notes_name), fixture_notes)
    fixture_files = [
      ["dmg", "LidPilot-#{fixture_label}.dmg", fixture_dmg],
      ["update-archive", fixture_archive_name, fixture_archive],
      ["appcast", "appcast.xml", fixture_feed],
      ["release-notes", fixture_notes_name, fixture_notes]
    ].map do |name, path, bytes|
      { "name" => name, "path" => path, "sha256" => Digest::SHA256.hexdigest(bytes) }
    end
    fixture_manifest = {
      "version" => fixture_version,
      "releaseLabel" => fixture_label,
      "channel" => "stable",
      "hardwareValidation" => "approved",
      "profilingEnabled" => false,
      "build" => fixture_build,
      "feedURL" => STABLE_FEED,
      "downloadURL" => fixture_download,
      "files" => fixture_files
    }
    File.write(File.join(fixture_updates, "manifest.json"), JSON.pretty_generate(fixture_manifest) + "\n")
    fixture_defaults = defaults.merge("sparklePublicKey" => fixture_public_key)
    fixture_stable_info = validate_stable_site(Pathname(fixture_root), fixture_defaults)
    fail_validation("self-test did not validate a disposable signed stable fixture") unless fixture_stable_info.fetch(:manifest).fetch(:values).fetch("channel") == "stable"

    fixture_manifest_path = File.join(fixture_updates, "manifest.json")
    fixture_appcast_path = File.join(fixture_updates, "appcast.xml")
    original_fixture_manifest = File.binread(fixture_manifest_path)
    write_signed_fixture_feed = lambda do |body, label|
      signature = sign_fixture.call(body, label)
      bytes = body + "<!-- sparkle-signatures: edSignature: #{signature} length: #{body.bytesize} -->\n"
      File.binwrite(fixture_appcast_path, bytes)
      fixture_manifest.fetch("files").find { |entry| entry.fetch("name") == "appcast" }["sha256"] = Digest::SHA256.hexdigest(bytes)
      File.write(fixture_manifest_path, JSON.pretty_generate(fixture_manifest) + "\n")
      bytes
    end
    fixture_item = base_feed[/<item>.*?<\/item>/m]
    fail_validation("self-test could not locate the stable fixture item") unless fixture_item
    duplicated_item_feed = base_feed.sub("</channel>", "#{fixture_item}</channel>")
    write_signed_fixture_feed.call(duplicated_item_feed, "stable-appcast-duplicate-item")
    expect_failure("stable appcast rejects multiple update items", expected: "exactly one RSS update item") do
      validate_stable_site(Pathname(fixture_root), fixture_defaults)
    end

    fixture_channel = base_feed[/<channel>.*?<\/channel>/m]
    fail_validation("self-test could not locate the stable fixture channel") unless fixture_channel
    duplicated_channel_feed = base_feed.sub("</rss>", "#{fixture_channel}</rss>")
    write_signed_fixture_feed.call(duplicated_channel_feed, "stable-appcast-duplicate-channel")
    expect_failure("stable appcast rejects multiple RSS channels", expected: "exactly one RSS channel") do
      validate_stable_site(Pathname(fixture_root), fixture_defaults)
    end

    fixture_enclosure = base_feed[/<enclosure\b[^>]*\/>/]
    fail_validation("self-test could not locate the stable fixture enclosure") unless fixture_enclosure
    duplicated_enclosure_feed = base_feed.sub("</item>", "#{fixture_enclosure}</item>")
    write_signed_fixture_feed.call(duplicated_enclosure_feed, "stable-appcast-duplicate-enclosure")
    expect_failure("stable appcast rejects multiple RSS enclosures", expected: "exactly one RSS enclosure") do
      validate_stable_site(Pathname(fixture_root), fixture_defaults)
    end

    other_namespace_feed = base_feed
      .sub('xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle"', 'xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" xmlns:other="urn:unexpected"')
      .sub("<sparkle:version>", "<other:version>")
      .sub("</sparkle:version>", "</other:version>")
    write_signed_fixture_feed.call(other_namespace_feed, "stable-appcast-wrong-element-namespace")
    expect_failure("stable appcast rejects wrong Sparkle element namespace", expected: "Sparkle build version must use the expected XML namespace") do
      validate_stable_site(Pathname(fixture_root), fixture_defaults)
    end

    other_attribute_namespace_feed = base_feed
      .sub('xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle"', 'xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" xmlns:other="urn:unexpected"')
      .sub("sparkle:edSignature=\"#{fixture_notes_signature}\"", "other:edSignature=\"#{fixture_notes_signature}\"")
    write_signed_fixture_feed.call(other_attribute_namespace_feed, "stable-appcast-wrong-attribute-namespace")
    expect_failure("stable appcast rejects wrong Sparkle attribute namespace", expected: "Sparkle release-notes signature must use the expected XML namespace") do
      validate_stable_site(Pathname(fixture_root), fixture_defaults)
    end
    fixture_manifest = JSON.parse(original_fixture_manifest)
    File.binwrite(fixture_appcast_path, fixture_feed)
    File.binwrite(fixture_manifest_path, original_fixture_manifest)

    fixture_asset_bytes = {
      "LidPilot-#{fixture_label}.dmg" => fixture_dmg,
      fixture_archive_name => fixture_archive,
      "appcast.xml" => fixture_feed,
      fixture_notes_name => fixture_notes
    }
    fixture_downloader = lambda do |url, destination, max_bytes:|
      uri = URI(url.to_s)
      fail_validation("self-test public asset URL was not versioned on github.com") unless uri.scheme == "https" && uri.host == "github.com" && uri.path.start_with?("/#{defaults.fetch("repository")}/releases/download/v#{fixture_label}/") && uri.query.nil?
      bytes = if uri.path.end_with?("/manifest.json")
                File.binread(File.join(fixture_updates, "manifest.json"))
              else
                fixture_asset_bytes.fetch(File.basename(uri.path))
              end
      fail_validation("self-test public fixture exceeded the requested byte limit") if bytes.bytesize > max_bytes
      File.binwrite(destination, bytes)
      bytes.bytesize
    end
    fixture_rc_label = "1.0.0-rc.5"
    fixture_rc_notes_name = "LidPilot-#{fixture_rc_label}.md"
    fixture_rc_notes = "Disposable RC test notes.\n"
    fixture_rc_archive = "disposable RC archive fixture\n"
    fixture_rc_notes_signature = sign_fixture.call(fixture_rc_notes, "rc-notes")
    fixture_rc_archive_signature = sign_fixture.call(fixture_rc_archive, "rc-archive")
    fixture_rc_notes_url = "#{DEFAULT_BRANDED_RC_FEED.delete_suffix("appcast.xml")}#{fixture_rc_notes_name}"
    fixture_rc_download_url = "https://github.com/#{defaults.fetch("repository")}/releases/download/v#{fixture_rc_label}/LidPilot-#{fixture_rc_label}.zip"
    fixture_rc_base_feed = <<~XML
      <rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle"><channel>
        <item><link>#{DEFAULT_BRANDED_RC_FEED}</link>
          <sparkle:version>43</sparkle:version>
          <sparkle:shortVersionString>1.0.0</sparkle:shortVersionString>
          <sparkle:minimumSystemVersion>15.0</sparkle:minimumSystemVersion>
          <sparkle:hardwareRequirements>arm64</sparkle:hardwareRequirements>
          <sparkle:releaseNotesLink sparkle:edSignature="#{fixture_rc_notes_signature}" sparkle:length="#{fixture_rc_notes.bytesize}">#{fixture_rc_notes_url}</sparkle:releaseNotesLink>
          <enclosure url="#{fixture_rc_download_url}" sparkle:edSignature="#{fixture_rc_archive_signature}" length="#{fixture_rc_archive.bytesize}" />
        </item>
      </channel></rss>
    XML
    fixture_rc_feed_signature = sign_fixture.call(fixture_rc_base_feed, "rc-appcast")
    File.binwrite(File.join(fixture_root, "rc", "appcast.xml"), fixture_rc_base_feed + "<!-- sparkle-signatures: edSignature: #{fixture_rc_feed_signature} length: #{fixture_rc_base_feed.bytesize} -->\n")
    File.binwrite(File.join(fixture_root, "rc", fixture_rc_notes_name), fixture_rc_notes)

    result = validate_pages_site(
      fixture_root,
      fixture_defaults,
      publication: :stable,
      verify_public_assets: true,
      downloader: fixture_downloader
    )
    fail_validation("self-test did not verify disposable public stable bytes") unless result.include?("verified public stable release bytes and signatures")
    expect_failure("RC publication mode rejects stable website files") do
      validate_pages_site(fixture_root, fixture_defaults, publication: :rc)
    end

    original_fixture_manifest = File.binread(File.join(fixture_updates, "manifest.json"))
    bad_archive = "X" + fixture_archive.byteslice(1, fixture_archive.bytesize - 1)
    fixture_manifest.fetch("files").find { |entry| entry.fetch("name") == "update-archive" }["sha256"] = Digest::SHA256.hexdigest(bad_archive)
    File.write(File.join(fixture_updates, "manifest.json"), JSON.pretty_generate(fixture_manifest) + "\n")
    fixture_asset_bytes[fixture_archive_name] = bad_archive
    expect_failure("public stable archive signature mismatch", expected: "public stable update archive Ed25519 signature verification failed") do
      bad_fixture_info = validate_stable_site(Pathname(fixture_root), fixture_defaults)
      verify_public_release_assets(fixture_root, fixture_defaults, bad_fixture_info, downloader: fixture_downloader)
    end
    File.binwrite(File.join(fixture_updates, "manifest.json"), original_fixture_manifest)
    fixture_manifest = JSON.parse(original_fixture_manifest)
    fixture_asset_bytes[fixture_archive_name] = fixture_archive

    expect_failure("stable public asset redirect host is not allowlisted", expected: "public release asset redirected to an unapproved host") do
      validate_public_asset_uri(URI("https://attacker.example/file"), initial: false)
    end
    [404, 410].each { |status| validate_stable_feed_absence_status(status) }
    [200, 301, 403, 500].each do |status|
      expect_failure("stable-feed absence status #{status}", expected: "stable feed is live or its state is ambiguous") { validate_stable_feed_absence_status(status) }
    end

    original_fixture_feed = File.binread(File.join(fixture_updates, "appcast.xml"))
    original_fixture_manifest = File.binread(File.join(fixture_updates, "manifest.json"))
    tampered_fixture_feed = original_fixture_feed.sub("<channel>", "<Channel>")
    File.binwrite(File.join(fixture_updates, "appcast.xml"), tampered_fixture_feed)
    fixture_manifest.fetch("files").find { |entry| entry.fetch("name") == "appcast" }["sha256"] = Digest::SHA256.hexdigest(tampered_fixture_feed)
    File.write(File.join(fixture_updates, "manifest.json"), JSON.pretty_generate(fixture_manifest) + "\n")
    expect_failure("tampered stable feed signature", expected: "stable appcast feed Ed25519 signature verification failed") do
      validate_stable_site(Pathname(fixture_root), fixture_defaults)
    end
    File.binwrite(File.join(fixture_updates, "appcast.xml"), original_fixture_feed)
    File.binwrite(File.join(fixture_updates, "manifest.json"), original_fixture_manifest)
    fixture_manifest = JSON.parse(original_fixture_manifest)

    original_fixture_notes = File.binread(File.join(fixture_updates, fixture_notes_name))
    tampered_fixture_notes = original_fixture_notes + "tampered\n"
    File.binwrite(File.join(fixture_updates, fixture_notes_name), tampered_fixture_notes)
    fixture_manifest.fetch("files").find { |entry| entry.fetch("name") == "release-notes" }["sha256"] = Digest::SHA256.hexdigest(tampered_fixture_notes)
    File.write(File.join(fixture_updates, "manifest.json"), JSON.pretty_generate(fixture_manifest) + "\n")
    expect_failure("tampered stable release notes", expected: "stable release notes Ed25519 signature verification failed") do
      validate_stable_site(Pathname(fixture_root), fixture_defaults)
    end
    File.binwrite(File.join(fixture_updates, fixture_notes_name), original_fixture_notes)
    File.binwrite(File.join(fixture_updates, "manifest.json"), original_fixture_manifest)
    fixture_manifest = JSON.parse(original_fixture_manifest)

    fixture_manifest["files"][1]["sha256"] = "0" * 64
    File.write(File.join(fixture_updates, "manifest.json"), JSON.pretty_generate(fixture_manifest) + "\n")
    expect_failure("stable manifest archive hash mismatch", expected: "public update-archive bytes do not match the release manifest SHA-256") do
      bad_fixture_info = validate_stable_site(Pathname(fixture_root), fixture_defaults)
      verify_public_release_assets(fixture_root, fixture_defaults, bad_fixture_info, downloader: fixture_downloader)
    end

    [
      ["stable manifest enables profiling", "profilingEnabled", true],
      ["stable manifest uses the RC feed", "feedURL", DEFAULT_BRANDED_RC_FEED]
    ].each do |label, key, value|
      malformed_manifest = JSON.parse(original_fixture_manifest)
      malformed_manifest[key] = value
      File.write(File.join(fixture_updates, "manifest.json"), JSON.pretty_generate(malformed_manifest) + "\n")
      expected_message = key == "profilingEnabled" ? "must not enable profiling" : "feed URL must be canonical"
      expect_failure(label, expected: expected_message) { validate_stable_manifest(Pathname(fixture_root), fixture_defaults) }
    end
    malformed_manifest = JSON.parse(original_fixture_manifest)
    malformed_manifest.fetch("files").find { |entry| entry.fetch("name") == "dmg" }["path"] = "../LidPilot-1.0.0.dmg"
    File.write(File.join(fixture_updates, "manifest.json"), JSON.pretty_generate(malformed_manifest) + "\n")
    expect_failure("stable manifest path traversal", expected: "artifact path does not match its immutable filename") { validate_stable_manifest(Pathname(fixture_root), fixture_defaults) }
  end
  puts "Pages site validator self-tests passed"
end

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: validate_pages_site.rb [--website PATH] [--publication rc|stable] [--verify-public-assets] [--require-stable-feed-absent] [--self-test]"
  opts.on("--website PATH", "Validate this website directory (default: website)") { |value| options[:website] = value }
  opts.on("--publication CHANNEL", "Validate rc (default) or stable publication metadata") { |value| options[:publication] = value }
  opts.on("--verify-public-assets", "Fetch versioned stable GitHub Release assets and verify manifest hashes/signatures") { options[:verify_public_assets] = true }
  opts.on("--require-stable-feed-absent", "Require an anonymous stable-feed endpoint response of exactly HTTP 404 or 410") { options[:require_stable_absent] = true }
  opts.on("--self-test", "Validate the committed website and run focused rejection checks") { options[:self_test] = true }
end.parse!

begin
  defaults = JSON.parse(File.read(DEFAULTS_PATH))
  if options[:self_test]
    fail_validation("--self-test cannot be combined with publication network guards") if options[:verify_public_assets] || options[:require_stable_absent]
    self_test(defaults)
  else
    website = options[:website] || ROOT.join("website")
    publication = options.fetch(:publication, "rc").to_sym
    puts validate_pages_site(
      website,
      defaults,
      publication: publication,
      verify_public_assets: options.fetch(:verify_public_assets, false),
      require_stable_absent: options.fetch(:require_stable_absent, false)
    )
  end
rescue ValidationError => e
  warn "Pages site validation failed: #{e.message}"
  exit 1
rescue JSON::ParserError => e
  warn "Pages site validation failed: release defaults are not valid JSON: #{e.message}"
  exit 1
rescue OptionParser::ParseError => e
  warn e.message
  exit 64
end
