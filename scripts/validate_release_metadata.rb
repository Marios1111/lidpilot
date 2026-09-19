#!/usr/bin/env ruby
# frozen_string_literal: true

require "digest"
require "base64"
require "fileutils"
require "json"
require "optparse"
require "open3"
require "rexml/document"
require "tmpdir"
require "uri"

class ValidationError < StandardError; end

# Do not treat ordinary XML tags as placeholders. Only explicit template
# markers and reserved/example hosts are rejected.
PLACEHOLDER = /(example\.(com|org|net|test)|localhost|127\.0\.0\.1|\.invalid\b|YOUR[_-]?[A-Z0-9_-]*|CHANGE[_-]?ME|REPLACE[_-]?ME|<\s*(?:YOUR|CHANGE|REPLACE|PLACEHOLDER)[^>]*>)/i

def fail_validation(message)
  raise ValidationError, message
end

def require_regular_file(path, label)
  fail_validation("#{label} is missing: #{path}") unless File.file?(path)
  fail_validation("#{label} must not be a symlink: #{path}") if File.symlink?(path)
end

def require_executable_file(path, label)
  require_regular_file(path, label)
  fail_validation("#{label} is not executable: #{path}") unless File.executable?(path)
end

def require_directory(path, label)
  fail_validation("#{label} is missing: #{path}") unless File.directory?(path)
  fail_validation("#{label} must not be a symlink: #{path}") if File.symlink?(path)
end

def require_real_url(value, label)
  fail_validation("#{label} is empty") if value.nil? || value.strip.empty?
  fail_validation("#{label} contains a placeholder") if value.match?(PLACEHOLDER)
  uri = URI.parse(value)
  fail_validation("#{label} must use HTTPS") unless uri.is_a?(URI::HTTPS)
  fail_validation("#{label} has no host") if uri.host.nil? || uri.host.empty?
  fail_validation("#{label} must not contain credentials") unless uri.userinfo.nil?
  fail_validation("#{label} must not contain a query or fragment") unless uri.query.nil? && uri.fragment.nil?
  uri
rescue URI::InvalidURIError => e
  fail_validation("#{label} is not a valid URL: #{e.message}")
end

def read_plist(path, label)
  require_regular_file(path, label)
  stdout, stderr, status = Open3.capture3("/usr/bin/plutil", "-convert", "json", "-o", "-", path)
  fail_validation("#{label} is not a valid plist: #{stderr.strip}") unless status.success?
  JSON.parse(stdout)
rescue JSON::ParserError => e
  fail_validation("#{label} is not valid plist JSON: #{e.message}")
end

def validate_appcast(path, version, build, feed_url, download_url, archive_size, notes_size, expected_notes_url)
  require_regular_file(path, "appcast")
  contents = File.read(path)
  fail_validation("appcast contains a placeholder") if contents.match?(PLACEHOLDER)
  document = REXML::Document.new(contents)
  fail_validation("appcast root must be rss") unless document.root && document.root.name == "rss"
  item = REXML::XPath.first(document, "//item")
  fail_validation("appcast has no update item") unless item
  version_node = REXML::XPath.first(item, "sparkle:version") || REXML::XPath.first(item, "*[local-name()='version']")
  short_node = REXML::XPath.first(item, "sparkle:shortVersionString") || REXML::XPath.first(item, "*[local-name()='shortVersionString']")
  fail_validation("appcast version is missing") unless version_node && version_node.text.to_s.strip == build.to_s
  fail_validation("appcast short version is missing") unless short_node && short_node.text.to_s.strip == version.to_s
  enclosure = REXML::XPath.first(item, "enclosure")
  fail_validation("appcast enclosure is missing") unless enclosure
  fail_validation("appcast enclosure URL does not match the immutable release URL") unless enclosure.attributes["url"] == download_url
  fail_validation("appcast enclosure is missing an Ed25519 signature") if enclosure.attributes["sparkle:edSignature"].to_s.strip.empty?
  fail_validation("appcast enclosure is missing its byte length") if enclosure.attributes["length"].to_s !~ /\A[1-9][0-9]*\z/
  fail_validation("appcast enclosure length does not match the archive") unless enclosure.attributes["length"].to_i == archive_size
  feed_link = REXML::XPath.first(item, "link") || REXML::XPath.first(document, "//channel/link")
  fail_validation("appcast is missing the configured feed URL in its link") unless feed_link && feed_link.text.to_s.strip == feed_url
  notes = REXML::XPath.first(item, "*[local-name()='releaseNotesLink']")
  fail_validation("appcast release-notes link is missing") unless notes
  notes_url = notes.text.to_s.strip
  parsed_notes_url = require_real_url(notes_url, "release-notes URL")
  fail_validation("appcast release-notes URL does not match the Pages publication URL") unless parsed_notes_url.to_s == expected_notes_url
  fail_validation("appcast release-notes link is missing an Ed25519 signature") if notes.attributes["sparkle:edSignature"].to_s.strip.empty?
  fail_validation("appcast release-notes link is missing its byte length") if notes.attributes["sparkle:length"].to_s !~ /\A[1-9][0-9]*\z/
  fail_validation("appcast release-notes length does not match the notes file") unless notes.attributes["sparkle:length"].to_i == notes_size
rescue REXML::ParseException => e
  fail_validation("appcast XML is malformed: #{e.message}")
end

def validate_publication_urls(feed, download, repository, version)
  return unless repository

  fail_validation("repository must be owner/repository") unless repository.match?(/\A[A-Za-z0-9-]+\/[A-Za-z0-9_.-]+\z/)
  owner, = repository.split("/", 2)
  fail_validation("Pages URL must use the repository owner's GitHub Pages HTTPS host") unless feed.port == 443 && feed.host.to_s.downcase == "#{owner.downcase}.github.io"
  fail_validation("Pages URL must point to an appcast.xml path") unless feed.path.to_s.end_with?("/appcast.xml")
  fail_validation("release download URL must use github.com") unless download.host.to_s.downcase == "github.com"
  expected_download = "https://github.com/#{repository}/releases/download/v#{version}/LidPilot-#{version}.zip"
  fail_validation("release download URL must exactly match the immutable GitHub Release asset") unless download.to_s == expected_download
end

def validate_bundle(bundle, version, build, team, feed_url)
  require_directory(bundle, "application bundle (run scripts/release.sh export first)")
  app_info = read_plist(File.join(bundle, "Contents", "Info.plist"), "application Info.plist")
  fail_validation("application bundle identifier is wrong") unless app_info["CFBundleIdentifier"] == "com.lidpilot.app"
  fail_validation("application version is wrong") unless app_info["CFBundleShortVersionString"].to_s == version.to_s
  fail_validation("application build is wrong") unless app_info["CFBundleVersion"].to_s == build.to_s
  fail_validation("automatic Sparkle checks must be enabled") unless app_info["SUEnableAutomaticChecks"] == true
  fail_validation("Sparkle check interval must be one day") unless app_info["SUScheduledCheckInterval"].to_i == 86_400
  fail_validation("Sparkle must not install automatically") unless app_info["SUAutomaticallyUpdate"] == false
  fail_validation("Sparkle automatic updates must be disabled") unless app_info["SUAllowsAutomaticUpdates"] == false
  fail_validation("Sparkle system profiling must be disabled") unless app_info["SUEnableSystemProfiling"] == false
  fail_validation("Sparkle must verify before extraction") unless app_info["SUVerifyUpdateBeforeExtraction"] == true
  fail_validation("Sparkle must require signed feeds") unless app_info["SURequireSignedFeed"] == true
  fail_validation("signed-feed expiration must be zero") unless app_info["SUSignedFeedFailureExpirationInterval"].to_i.zero?
  fail_validation("multiple application instances must be prohibited") unless app_info["LSMultipleInstancesProhibited"] == true
  if feed_url
    fail_validation("application feed URL does not match the release input") unless app_info["SUFeedURL"].to_s == feed_url.to_s
    public_key = app_info["SUPublicEDKey"].to_s
    fail_validation("application Sparkle public key is empty") if public_key.strip.empty?
    fail_validation("application Sparkle public key contains a placeholder") if public_key.match?(PLACEHOLDER)
    begin
      fail_validation("application Sparkle public key must decode to 32 bytes") unless Base64.strict_decode64(public_key).bytesize == 32
    rescue ArgumentError
      fail_validation("application Sparkle public key is not valid Base64")
    end
  end
  if team
    fail_validation("application team identifier is missing") unless app_info["LidPilotTeamIdentifier"].to_s == team.to_s
  end

  helper = File.join(bundle, "Contents", "Library", "HelperTools", "LidPilotHelper")
  require_regular_file(helper, "embedded helper")
  fail_validation("embedded helper is not executable") unless File.executable?(helper)
  daemon = File.join(bundle, "Contents", "Library", "LaunchDaemons", "com.lidpilot.app.helper.plist")
  daemon_info = read_plist(daemon, "embedded LaunchDaemon plist")
  fail_validation("LaunchDaemon label is wrong") unless daemon_info["Label"] == "com.lidpilot.app.helper"
  fail_validation("LaunchDaemon BundleProgram is wrong") unless daemon_info["BundleProgram"] == "Contents/Library/HelperTools/LidPilotHelper"
  fail_validation("LaunchDaemon MachServices entry is missing") unless daemon_info.dig("MachServices", "com.lidpilot.app.helper") == true
  fail_validation("LaunchDaemon must run at load") unless daemon_info["RunAtLoad"] == true
  fail_validation("LaunchDaemon must keep the helper alive") unless daemon_info["KeepAlive"] == true
  fail_validation("LaunchDaemon ThrottleInterval must be 10") unless daemon_info["ThrottleInterval"].to_i == 10
  fail_validation("LaunchDaemon process type must be Background") unless daemon_info["ProcessType"] == "Background"
  fail_validation("LaunchDaemon must not abandon its process group") if daemon_info.key?("AbandonProcessGroup")
end

def verify_signatures(options)
  document = REXML::Document.new(File.read(options.fetch(:appcast)))
  item = REXML::XPath.first(document, "//item")
  enclosure = REXML::XPath.first(item, "enclosure")
  notes = REXML::XPath.first(item, "*[local-name()='releaseNotesLink']")
  fail_validation("signed release notes are missing") unless notes && !notes.attributes["sparkle:edSignature"].to_s.empty?
  fail_validation("release-notes length does not match") unless notes.attributes["sparkle:length"].to_i == File.size(options.fetch(:notes))
  key_file = options.fetch(:private_key_file)
  tool = options.fetch(:sign_tool)
  require_executable_file(tool, "Sparkle sign_update tool (set SPARKLE_TOOLS_DIR to Sparkle 2.10.0/bin)")
  require_regular_file(key_file, "Sparkle private key input (set SPARKLE_PRIVATE_KEY_FILE to a protected key file)")
  verifier = File.join(__dir__, "verify_update_signature.swift")
  require_regular_file(verifier, "archive signature verifier")
  [[options.fetch(:archive), enclosure.attributes["sparkle:edSignature"]],
   [options.fetch(:notes), notes.attributes["sparkle:edSignature"]],
   [options.fetch(:appcast), nil]].each do |file, signature|
    command = [tool, "--verify", "--ed-key-file", key_file, file]
    command << signature if signature
    _, _, status = Open3.capture3(*command)
    fail_validation("Sparkle signature verification failed for #{File.basename(file)}") unless status.success?
  end
  info = read_plist(File.join(options.fetch(:bundle), "Contents", "Info.plist"), "application Info.plist")
  _, _, status = Open3.capture3("xcrun", "swift", verifier, options.fetch(:archive), info.fetch("SUPublicEDKey"), enclosure.attributes["sparkle:edSignature"])
  fail_validation("archive signature does not match the application public key") unless status.success?
end

def validate(options)
  version = options.fetch(:version)
  build = options.fetch(:build)
  fail_validation("version must be numeric x.y.z") unless version.match?(/\A[0-9]+\.[0-9]+\.[0-9]+\z/)
  fail_validation("build must be a positive integer") unless build.match?(/\A[1-9][0-9]*\z/)
  feed = require_real_url(options.fetch(:feed_url), "feed URL")
  download = require_real_url(options.fetch(:download_url), "download URL")
  fail_validation("download URL must not use /latest/") if download.path.to_s.include?("/latest/")
  fail_validation("download URL must identify this version") unless download.path.to_s.include?(version) || download.path.to_s.include?("v#{version}")
  validate_publication_urls(feed, download, options[:repository], version)

  require_regular_file(options.fetch(:archive), "update archive")
  require_regular_file(options.fetch(:notes), "release notes")
  notes = File.read(options.fetch(:notes))
  fail_validation("release notes are empty") if notes.strip.empty?
  fail_validation("release notes contain a placeholder") if notes.match?(PLACEHOLDER)
  expected_notes_url = URI.join(feed.to_s, File.basename(options.fetch(:notes))).to_s
  validate_appcast(options.fetch(:appcast), version, build, feed.to_s, download.to_s, File.size(options.fetch(:archive)), File.size(options.fetch(:notes)), expected_notes_url)
  validate_bundle(options[:bundle], version, build, options[:team], options[:feed_url]) if options[:bundle]
  verify_signatures(options) if options[:sign_tool]
  digest = Digest::SHA256.file(options.fetch(:archive)).hexdigest
  { "version" => version, "build" => build, "archive" => File.basename(options.fetch(:archive)), "sha256" => digest }
end

def expect_failure(label)
  begin
    yield
  rescue ValidationError
    puts "self-test rejected #{label}"
    return
  end
  fail_validation("self-test expected #{label} to fail")
end

def self_test
  Dir.mktmpdir("lidpilot-release-validator-") do |dir|
    archive = File.join(dir, "LidPilot-1.0.0.zip")
    notes = File.join(dir, "LidPilot-1.0.0.md")
    appcast = File.join(dir, "appcast.xml")
    File.binwrite(archive, "fixture bytes")
    File.write(notes, "fixture notes")
    base = {
      archive: archive,
      notes: notes,
      version: "1.0.0",
      build: "1",
      feed_url: "https://lidpilot.github.io/lidpilot/appcast.xml",
      download_url: "https://github.com/lidpilot/lidpilot/releases/download/v1.0.0/LidPilot-1.0.0.zip",
      repository: "lidpilot/lidpilot"
    }
    File.write(appcast, "<rss>")
    expect_failure("malformed appcast") { validate(base.merge(appcast: appcast)) }
    File.write(appcast, <<~XML)
      <rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle"><channel>
        <item><link>https://lidpilot.github.io/lidpilot/appcast.xml</link>
          <sparkle:version>1</sparkle:version><sparkle:shortVersionString>1.0.0</sparkle:shortVersionString>
          <sparkle:releaseNotesLink sparkle:edSignature="fixture" sparkle:length="13">https://lidpilot.github.io/lidpilot/LidPilot-1.0.0.md</sparkle:releaseNotesLink>
          <enclosure url="https://github.com/lidpilot/lidpilot/releases/download/v1.0.0/LidPilot-1.0.0.zip" sparkle:edSignature="fixture" length="13" />
        </item></channel></rss>
    XML
    accepted = validate(base.merge(appcast: appcast))
    fail_validation("self-test expected a valid appcast to pass") if accepted["sha256"].to_s.empty?
    puts "self-test accepted valid appcast"
    expect_failure("wrong Pages origin") do
      validate(base.merge(feed_url: "https://other.github.io/lidpilot/appcast.xml"))
    end
    expect_failure("wrong GitHub Release owner/repository") do
      validate(base.merge(download_url: "https://github.com/other/lidpilot/releases/download/v1.0.0/LidPilot-1.0.0.zip"))
    end
    expect_failure("credential-bearing publication URL") do
      validate(base.merge(feed_url: "https://user:pass@lidpilot.github.io/lidpilot/appcast.xml"))
    end
    expect_failure("wrong release-notes origin") do
      wrong_notes = File.read(appcast).sub("https://lidpilot.github.io/lidpilot/LidPilot-1.0.0.md", "https://other.github.io/lidpilot/LidPilot-1.0.0.md")
      File.write(appcast, wrong_notes)
      validate(base.merge(appcast: appcast))
    end
    File.write(appcast, File.read(appcast).sub("https://other.github.io/lidpilot/LidPilot-1.0.0.md", "https://lidpilot.github.io/lidpilot/LidPilot-1.0.0.md"))
    expect_failure("appcast enclosure publication mismatch") do
      wrong_asset = File.read(appcast).sub("https://github.com/lidpilot/lidpilot/releases/download/v1.0.0/LidPilot-1.0.0.zip", "https://github.com/lidpilot/lidpilot/releases/download/v1.0.0/LidPilot-0.9.0.zip")
      File.write(appcast, wrong_asset)
      validate(base.merge(appcast: appcast))
    end
    File.write(appcast, File.read(appcast).sub("https://github.com/lidpilot/lidpilot/releases/download/v1.0.0/LidPilot-0.9.0.zip", "https://github.com/lidpilot/lidpilot/releases/download/v1.0.0/LidPilot-1.0.0.zip"))
    expect_failure("placeholder feed URL") { validate(base.merge(appcast: appcast, feed_url: "https://example.com/appcast.xml")) }
    bundle = File.join(dir, "LidPilot.app")
    FileUtils.mkdir_p(File.join(bundle, "Contents"))
    expect_failure("missing application bundle paths") { validate(base.merge(appcast: appcast, bundle: bundle)) }
  end
  puts "release metadata validator self-tests passed"
end

options = {}
parser = OptionParser.new do |opts|
  opts.banner = "Usage: validate_release_metadata.rb [options]"
  opts.on("--archive PATH") { |value| options[:archive] = value }
  opts.on("--appcast PATH") { |value| options[:appcast] = value }
  opts.on("--notes PATH") { |value| options[:notes] = value }
  opts.on("--bundle PATH") { |value| options[:bundle] = value }
  opts.on("--feed-url URL") { |value| options[:feed_url] = value }
  opts.on("--download-url URL") { |value| options[:download_url] = value }
  opts.on("--repository OWNER/REPOSITORY") { |value| options[:repository] = value }
  opts.on("--version VERSION") { |value| options[:version] = value }
  opts.on("--build BUILD") { |value| options[:build] = value }
  opts.on("--team TEAM") { |value| options[:team] = value }
  opts.on("--sign-tool PATH") { |value| options[:sign_tool] = value }
  opts.on("--private-key-file PATH") { |value| options[:private_key_file] = value }
  opts.on("--self-test") { options[:self_test] = true }
end

begin
  parser.parse!(ARGV)
  if options[:self_test]
    self_test
  else
    %i[archive appcast notes feed_url download_url repository version build].each do |key|
      fail_validation("missing --#{key.to_s.tr("_", "-")}") unless options[key]
    end
    result = validate(options)
    puts JSON.generate(result)
  end
rescue ValidationError => e
  warn "release metadata validation failed: #{e.message}"
  exit 1
rescue OptionParser::ParseError => e
  warn e.message
  warn parser
  exit 64
end
