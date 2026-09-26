#!/usr/bin/env ruby
# frozen_string_literal: true

require "base64"
require "digest"
require "fileutils"
require "json"
require "open3"
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

def validate_feed_signature(raw, public_key)
  match = SIGNATURE_BLOCK.match(raw)
  fail_validation("RC appcast must contain exactly one Sparkle feed signature block") unless match && raw.scan(SIGNATURE_BLOCK).length == 1
  signed_length = Integer(match[2], 10)
  fail_validation("RC appcast signed-byte length does not match the signature block offset") unless signed_length == match.begin(0)
  trailer = raw.byteslice(match.end(0), raw.bytesize - match.end(0)).to_s.strip
  unless trailer.empty? || trailer == POST_SIGNATURE_WARNING
    fail_validation("RC appcast has bytes outside its signature block other than Sparkle's known warning comment")
  end

  signature = decode_signature(match[1], "RC appcast feed signature")
  signed_bytes = raw.byteslice(0, match.begin(0))
  verify_ed25519(public_key, signature, signed_bytes, "RC appcast feed")
end

def validate_rc_feed_url(value)
  return :legacy if value == LEGACY_RC_FEED
  return :branded if value == DEFAULT_BRANDED_RC_FEED

  fail_validation("RC appcast link must use the exact branded RC URL or the explicitly preserved legacy RC URL")
end

def validate_pages_site(site_root, defaults)
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
  fail_validation("stable feed publication is gated until a real signed stable artifact exists") if [
    site_root.join("appcast.xml"), site_root.join("updates", "appcast.xml")
  ].any? { |path| File.exist?(path) || File.symlink?(path) }

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

  "validated #{release_label} Pages metadata (#{feed_kind == :legacy ? "preserved legacy" : "branded"} RC feed)"
rescue REXML::ParseException => e
  fail_validation("RC appcast XML is malformed: #{e.message}")
rescue KeyError => e
  fail_validation("release defaults are missing #{e.key}")
rescue URI::InvalidURIError => e
  fail_validation("RC Pages URL is invalid: #{e.message}")
end

def expect_failure(label)
  rejected = false
  begin
    yield
  rescue ValidationError
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
  puts validate_pages_site(site, defaults)
  fail_validation("self-test did not accept branded RC URL") unless validate_rc_feed_url(DEFAULT_BRANDED_RC_FEED) == :branded
  fail_validation("self-test did not accept the explicit legacy RC URL") unless validate_rc_feed_url(LEGACY_RC_FEED) == :legacy
  expect_failure("legacy stable GitHub Pages URL") { validate_rc_feed_url("https://marios1111.github.io/lidpilot/appcast.xml") }
  expect_failure("unrelated RC origin") { validate_rc_feed_url("https://attacker.example/rc/appcast.xml") }

  Dir.mktmpdir("lidpilot-pages-validator-") do |dir|
    copy = File.join(dir, "website")
    FileUtils.cp_r("#{site}/.", copy)
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
  end
  puts "Pages site validator self-tests passed"
end

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: validate_pages_site.rb [--website PATH] [--self-test]"
  opts.on("--website PATH", "Validate this website directory (default: website)") { |value| options[:website] = value }
  opts.on("--self-test", "Validate the committed website and run focused rejection checks") { options[:self_test] = true }
end.parse!

begin
  defaults = JSON.parse(File.read(DEFAULTS_PATH))
  if options[:self_test]
    self_test(defaults)
  else
    website = options[:website] || ROOT.join("website")
    puts validate_pages_site(website, defaults)
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
