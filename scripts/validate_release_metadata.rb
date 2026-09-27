#!/usr/bin/env ruby
# frozen_string_literal: true

require "digest"
require "base64"
require "cgi"
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
PLACEHOLDER = /(example\.(com|org|net|test)|localhost|127\.0\.0\.1|\.invalid\b|\bYOUR[_-][A-Z0-9_-]+\b|\b(?-i:YOUR[A-Z0-9]+)\b|\bCHANGE[_-]?ME\b|\bREPLACE[_-]?ME\b|<\s*(?:YOUR|CHANGE|REPLACE|PLACEHOLDER)(?:[_-][A-Z0-9_-]+)?\s*>)/i
RELEASE_DEFAULTS_PATH = File.join(File.dirname($PROGRAM_NAME), "..", "Config", "ReleaseDefaults.json")

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

def validate_release_label(version, release_label, channel)
  fail_validation("release channel must be stable or rc") unless %w[stable rc].include?(channel)
  expected = case channel
             when "stable"
               version
             when "rc"
               fail_validation("release label must match VERSION-rc.N for the selected channel") unless release_label.match?(/\A#{Regexp.escape(version)}-rc\.[1-9][0-9]*\z/)
               release_label
             end
  fail_validation("stable release label must equal the numeric marketing version") unless release_label == expected
  release_label
end

def load_release_defaults
  require_regular_file(RELEASE_DEFAULTS_PATH, "release defaults")
  defaults = JSON.parse(File.read(RELEASE_DEFAULTS_PATH))
  %w[repository stableFeedURL rcFeedURL sparklePublicKey].each do |key|
    fail_validation("release defaults are missing #{key}") unless defaults[key].is_a?(String) && !defaults[key].empty?
  end
  defaults
rescue JSON::ParserError => e
  fail_validation("release defaults are not valid JSON: #{e.message}")
end

def validate_publication_urls(feed, download, repository, release_label, channel)
  fail_validation("repository must be owner/repository") unless repository.match?(/\A[A-Za-z0-9-]+\/[A-Za-z0-9_.-]+\z/)
  expected_feed = if channel == "rc"
                    "https://lidpilot.app/rc/appcast.xml"
                  else
                    "https://lidpilot.app/updates/appcast.xml"
                  end
  fail_validation("Pages URL must exactly match the canonical #{channel} feed URL #{expected_feed}") unless feed.to_s == expected_feed
  fail_validation("release download URL must use github.com") unless download.host.to_s.downcase == "github.com"
  expected_download = "https://github.com/#{repository}/releases/download/v#{release_label}/LidPilot-#{release_label}.zip"
  fail_validation("release download URL must exactly match the immutable GitHub Release asset") unless download.to_s == expected_download
end

def release_configuration(version, environment = ENV)
  fail_validation("version must be numeric x.y.z") unless version.match?(/\A[0-9]+\.[0-9]+\.[0-9]+\z/)
  channel = environment.fetch("LIDPILOT_RELEASE_CHANNEL", "stable")
  fail_validation("LIDPILOT_RELEASE_CHANNEL must be stable or rc") unless %w[stable rc].include?(channel)

  if channel == "rc"
    rc_number = environment["LIDPILOT_RC_NUMBER"].to_s
    fail_validation("LIDPILOT_RC_NUMBER must be a positive integer for an RC") unless rc_number.match?(/\A[1-9][0-9]*\z/)
    fail_validation("LIDPILOT_RC_TESTING_APPROVED=1 is required for an RC") unless environment["LIDPILOT_RC_TESTING_APPROVED"] == "1"
    release_label = "#{version}-rc.#{rc_number}"
  else
    release_label = version
  end

  validate_release_label(version, release_label, channel)
  defaults = load_release_defaults
  repository = environment["LIDPILOT_GITHUB_REPOSITORY"] || defaults.fetch("repository")
  expected_feed = channel == "rc" ? defaults.fetch("rcFeedURL") : defaults.fetch("stableFeedURL")
  feed_url = environment["LIDPILOT_PAGES_URL"] || expected_feed
  expected_download = "https://github.com/#{repository}/releases/download/v#{release_label}/LidPilot-#{release_label}.zip"
  download_url = environment["LIDPILOT_RELEASE_DOWNLOAD_URL"] || expected_download
  sparkle_public_key = environment["LIDPILOT_SPARKLE_PUBLIC_KEY"] || defaults.fetch("sparklePublicKey")
  fail_validation("LIDPILOT_SPARKLE_PUBLIC_KEY contains a placeholder") if sparkle_public_key.match?(PLACEHOLDER)
  begin
    fail_validation("LIDPILOT_SPARKLE_PUBLIC_KEY must decode to 32 bytes") unless Base64.strict_decode64(sparkle_public_key).bytesize == 32
  rescue ArgumentError
    fail_validation("LIDPILOT_SPARKLE_PUBLIC_KEY is not valid Base64")
  end
  feed = require_real_url(feed_url, "feed URL")
  download = require_real_url(download_url, "download URL")
  fail_validation("release download URL must not use /latest/") if download.path.to_s.include?("/latest/")
  validate_publication_urls(feed, download, repository, release_label, channel)

  hardware_validation = if channel == "rc"
                          "pending"
                        elsif environment["LIDPILOT_HARDWARE_APPROVED"] == "1"
                          "approved"
                        else
                          "pending"
                        end
  {
    "channel" => channel,
    "releaseLabel" => release_label,
    "repository" => repository,
    "feedURL" => feed_url,
    "downloadURL" => download_url,
    "sparklePublicKey" => sparkle_public_key,
    "hardwareValidation" => hardware_validation
  }
rescue URI::InvalidURIError => e
  fail_validation("release URL is not valid: #{e.message}")
end

def assert_monotonic_build(current_build, previous_build)
  current = current_build.to_s
  previous = previous_build.to_s
  fail_validation("current build must be a positive integer") unless current.match?(/\A[1-9][0-9]*\z/)
  fail_validation("previous build must be a positive integer") unless previous.match?(/\A[1-9][0-9]*\z/)
  fail_validation("build #{current} is not greater than the last recorded release build #{previous}") unless Integer(current, 10) > Integer(previous, 10)
end

def check_monotonic_build_file(current_build, state_file)
  return unless File.exist?(state_file)

  state = JSON.parse(File.read(state_file))
  assert_monotonic_build(current_build, state.fetch("build"))
rescue JSON::ParserError, KeyError => e
  fail_validation("release state is invalid: #{e.message}")
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

def validate_bundle(bundle, version, build, team, feed_url)
  require_directory(bundle, "application bundle (run scripts/release.sh export first)")
  app_info = read_plist(File.join(bundle, "Contents", "Info.plist"), "application Info.plist")
  fail_validation("application bundle identifier is wrong") unless app_info["CFBundleIdentifier"] == "com.lidpilot.app"
  fail_validation("application helper identifier is wrong") unless app_info["LidPilotHelperIdentifier"] == "com.lidpilot.app.helper"
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
  fail_validation("LaunchDaemon process type must be Standard") unless daemon_info["ProcessType"] == "Standard"
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
  release_label = options.fetch(:release_label)
  channel = options.fetch(:channel)
  build = options.fetch(:build)
  hardware_validation = options.fetch(:hardware_validation)
  fail_validation("version must be numeric x.y.z") unless version.match?(/\A[0-9]+\.[0-9]+\.[0-9]+\z/)
  validate_release_label(version, release_label, channel)
  fail_validation("build must be a positive integer") unless build.match?(/\A[1-9][0-9]*\z/)
  expected_hardware_validation = channel == "rc" ? "pending" : "approved"
  fail_validation("#{channel} manifest hardware validation must be #{expected_hardware_validation}") unless hardware_validation == expected_hardware_validation
  feed = require_real_url(options.fetch(:feed_url), "feed URL")
  download = require_real_url(options.fetch(:download_url), "download URL")
  fail_validation("download URL must not use /latest/") if download.path.to_s.include?("/latest/")
  validate_publication_urls(feed, download, options.fetch(:repository), release_label, channel)

  require_regular_file(options.fetch(:archive), "update archive")
  require_regular_file(options.fetch(:notes), "release notes")
  fail_validation("update archive name must use release label #{release_label}") unless File.basename(options.fetch(:archive)) == "LidPilot-#{release_label}.zip"
  fail_validation("release notes name must use release label #{release_label}") unless File.basename(options.fetch(:notes)) == "LidPilot-#{release_label}.md"
  notes = File.read(options.fetch(:notes))
  fail_validation("release notes are empty") if notes.strip.empty?
  fail_validation("release notes contain a placeholder") if notes.match?(PLACEHOLDER)
  expected_notes_url = URI.join(feed.to_s, File.basename(options.fetch(:notes))).to_s
  validate_appcast(options.fetch(:appcast), version, build, feed.to_s, download.to_s, File.size(options.fetch(:archive)), File.size(options.fetch(:notes)), expected_notes_url)
  validate_bundle(options[:bundle], version, build, options[:team], options[:feed_url]) if options[:bundle]
  verify_signatures(options) if options[:sign_tool]
  digest = Digest::SHA256.file(options.fetch(:archive)).hexdigest
  {
    "version" => version,
    "releaseLabel" => release_label,
    "channel" => channel,
    "hardwareValidation" => hardware_validation,
    "build" => build,
    "archive" => File.basename(options.fetch(:archive)),
    "sha256" => digest
  }
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

def fixture_plist_value(value)
  case value
  when true then "<true/>"
  when false then "<false/>"
  when Integer then "<integer>#{value}</integer>"
  when Hash
    entries = value.map do |key, nested_value|
      "<key>#{CGI.escapeHTML(key.to_s)}</key>#{fixture_plist_value(nested_value)}"
    end.join
    "<dict>#{entries}</dict>"
  else "<string>#{CGI.escapeHTML(value.to_s)}</string>"
  end
end

def write_fixture_plist(path, values)
  FileUtils.mkdir_p(File.dirname(path))
  entries = values.map do |key, value|
    "<key>#{CGI.escapeHTML(key)}</key>#{fixture_plist_value(value)}"
  end.join
  File.write(path, "<?xml version=\"1.0\" encoding=\"UTF-8\"?><plist version=\"1.0\"><dict>#{entries}</dict></plist>")
end

def write_fixture_appcast(path, options)
  feed_url = options.fetch(:feed_url)
  notes_url = URI.join(feed_url, File.basename(options.fetch(:notes))).to_s
  File.write(path, <<~XML)
    <rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle"><channel>
      <item><link>#{feed_url}</link>
        <sparkle:version>#{options.fetch(:build)}</sparkle:version>
        <sparkle:shortVersionString>#{options.fetch(:version)}</sparkle:shortVersionString>
        <sparkle:releaseNotesLink sparkle:edSignature="fixture" sparkle:length="#{File.size(options.fetch(:notes))}">#{notes_url}</sparkle:releaseNotesLink>
        <enclosure url="#{options.fetch(:download_url)}" sparkle:edSignature="fixture" length="#{File.size(options.fetch(:archive))}" />
      </item></channel></rss>
  XML
end

def write_fixture_bundle(bundle, options)
  contents = File.join(bundle, "Contents")
  public_key = Base64.strict_encode64("x" * 32)
  write_fixture_plist(File.join(contents, "Info.plist"), {
    "CFBundleIdentifier" => "com.lidpilot.app",
    "LidPilotHelperIdentifier" => "com.lidpilot.app.helper",
    "CFBundleShortVersionString" => options.fetch(:version),
    "CFBundleVersion" => options.fetch(:build),
    "SUFeedURL" => options.fetch(:feed_url),
    "SUPublicEDKey" => public_key,
    "SUEnableAutomaticChecks" => true,
    "SUScheduledCheckInterval" => 86_400,
    "SUAutomaticallyUpdate" => false,
    "SUAllowsAutomaticUpdates" => false,
    "SUEnableSystemProfiling" => false,
    "SUVerifyUpdateBeforeExtraction" => true,
    "SURequireSignedFeed" => true,
    "SUSignedFeedFailureExpirationInterval" => 0,
    "LSMultipleInstancesProhibited" => true,
    "LidPilotTeamIdentifier" => "L69774LN97"
  })

  helper = File.join(contents, "Library", "HelperTools", "LidPilotHelper")
  FileUtils.mkdir_p(File.dirname(helper))
  File.write(helper, "fixture helper")
  FileUtils.chmod(0o755, helper)

  write_fixture_plist(File.join(contents, "Library", "LaunchDaemons", "com.lidpilot.app.helper.plist"), {
    "Label" => "com.lidpilot.app.helper",
    "BundleProgram" => "Contents/Library/HelperTools/LidPilotHelper",
    "MachServices" => { "com.lidpilot.app.helper" => true },
    "RunAtLoad" => true,
    "KeepAlive" => true,
    "ThrottleInterval" => 10,
    "ProcessType" => "Standard"
  })
end

def expect_equal(actual, expected, label)
  fail_validation("self-test expected #{label} to be #{expected.inspect}, got #{actual.inspect}") unless actual == expected
end

def self_test
  fail_validation("ordinary release prose was mistaken for a placeholder") if "Keep your settings during helper replacement.".match?(PLACEHOLDER)
  %w[YOUR_TEAM YOURTEAM REPLACE_ME replaceme CHANGE-ME <PLACEHOLDER>].each do |marker|
    fail_validation("placeholder detection missed #{marker}") unless marker.match?(PLACEHOLDER)
  end
  Dir.mktmpdir("lidpilot-release-validator-") do |dir|
    stable_config = release_configuration("1.0.0", { "LIDPILOT_RELEASE_CHANNEL" => "stable", "LIDPILOT_RC_NUMBER" => "7", "LIDPILOT_RC_TESTING_APPROVED" => "1" })
    expect_equal(stable_config.fetch("releaseLabel"), "1.0.0", "stable release label")
    expect_equal(stable_config.fetch("feedURL"), "https://lidpilot.app/updates/appcast.xml", "stable feed default")
    expect_equal(stable_config.fetch("downloadURL"), "https://github.com/Marios1111/lidpilot/releases/download/v1.0.0/LidPilot-1.0.0.zip", "stable immutable URL")

    rc_config = release_configuration("1.0.0", {
      "LIDPILOT_RELEASE_CHANNEL" => "rc",
      "LIDPILOT_RC_NUMBER" => "4",
      "LIDPILOT_RC_TESTING_APPROVED" => "1",
      "LIDPILOT_HARDWARE_APPROVED" => "1"
    })
    expect_equal(rc_config.fetch("releaseLabel"), "1.0.0-rc.4", "RC release label")
    expect_equal(rc_config.fetch("feedURL"), "https://lidpilot.app/rc/appcast.xml", "RC feed default")
    expect_equal(rc_config.fetch("downloadURL"), "https://github.com/Marios1111/lidpilot/releases/download/v1.0.0-rc.4/LidPilot-1.0.0-rc.4.zip", "RC immutable URL")
    expect_equal(rc_config.fetch("hardwareValidation"), "pending", "RC hardware status even when hardware approval is present")

    expect_failure("missing RC testing consent") do
      release_configuration("1.0.0", { "LIDPILOT_RELEASE_CHANNEL" => "rc", "LIDPILOT_RC_NUMBER" => "4" })
    end
    expect_failure("invalid RC number") do
      release_configuration("1.0.0", { "LIDPILOT_RELEASE_CHANNEL" => "rc", "LIDPILOT_RC_NUMBER" => "0", "LIDPILOT_RC_TESTING_APPROVED" => "1" })
    end
    expect_failure("invalid release label") do
      validate_release_label("1.0.0", "1.0.0-rc.04", "rc")
    end
    expect_failure("unknown release channel") do
      release_configuration("1.0.0", { "LIDPILOT_RELEASE_CHANNEL" => "nightly" })
    end
    state_file = File.join(dir, "last-release.json")
    File.write(state_file, JSON.generate("build" => "10"))
    expect_failure("non-monotonic state build") { check_monotonic_build_file("10", state_file) }
    check_monotonic_build_file("11", state_file)
    puts "self-test accepted a strictly monotonic build"

    archive = File.join(dir, "LidPilot-1.0.0.zip")
    notes = File.join(dir, "LidPilot-1.0.0.md")
    appcast = File.join(dir, "stable-appcast.xml")
    File.binwrite(archive, "fixture bytes")
    File.write(notes, "fixture notes")
    stable_base = {
      archive: archive,
      notes: notes,
      appcast: appcast,
      version: "1.0.0",
      release_label: "1.0.0",
      channel: "stable",
      build: "1",
      hardware_validation: "approved",
      feed_url: stable_config.fetch("feedURL"),
      download_url: stable_config.fetch("downloadURL"),
      repository: stable_config.fetch("repository")
    }
    File.write(appcast, "<rss>")
    expect_failure("malformed appcast") { validate(stable_base) }
    write_fixture_appcast(appcast, stable_base)
    accepted_stable = validate(stable_base)
    expect_equal(accepted_stable.fetch("releaseLabel"), "1.0.0", "validated stable label")
    expect_equal(accepted_stable.fetch("channel"), "stable", "validated stable channel")
    puts "self-test accepted stable metadata"

    expect_failure("stable metadata using the RC feed") do
      validate(stable_base.merge(feed_url: rc_config.fetch("feedURL")))
    end
    expect_failure("wrong Pages origin") do
      validate(stable_base.merge(feed_url: "https://marios1111.github.io/lidpilot/updates/appcast.xml"))
    end
    expect_failure("non-canonical stable feed path") do
      validate(stable_base.merge(feed_url: "https://lidpilot.app/appcast.xml"))
    end
    expect_failure("wrong GitHub Release owner/repository") do
      validate(stable_base.merge(download_url: "https://github.com/Other/lidpilot/releases/download/v1.0.0/LidPilot-1.0.0.zip"))
    end
    expect_failure("credential-bearing publication URL") do
      validate(stable_base.merge(feed_url: "https://user:pass@lidpilot.app/updates/appcast.xml"))
    end
    expect_failure("placeholder feed URL") do
      validate(stable_base.merge(feed_url: "https://example.com/appcast.xml"))
    end

    rc_archive = File.join(dir, "LidPilot-1.0.0-rc.4.zip")
    rc_notes = File.join(dir, "LidPilot-1.0.0-rc.4.md")
    rc_appcast = File.join(dir, "rc-appcast.xml")
    File.binwrite(rc_archive, "fixture RC bytes")
    File.write(rc_notes, "fixture RC notes")
    rc_base = {
      archive: rc_archive,
      notes: rc_notes,
      appcast: rc_appcast,
      version: "1.0.0",
      release_label: "1.0.0-rc.4",
      channel: "rc",
      build: "2",
      hardware_validation: "pending",
      feed_url: rc_config.fetch("feedURL"),
      download_url: rc_config.fetch("downloadURL"),
      repository: rc_config.fetch("repository"),
      team: "L69774LN97"
    }
    expect_failure("legacy GitHub Pages URL for a newly signed RC") do
      validate(rc_base.merge(feed_url: "https://marios1111.github.io/lidpilot/rc/appcast.xml"))
    end
    write_fixture_appcast(rc_appcast, rc_base)
    bundle = File.join(dir, "LidPilot.app")
    write_fixture_bundle(bundle, rc_base)
    accepted_rc = validate(rc_base.merge(bundle: bundle))
    daemon_path = File.join(bundle, "Contents", "Library", "LaunchDaemons", "com.lidpilot.app.helper.plist")
    daemon_fixture = read_plist(daemon_path, "fixture LaunchDaemon")
    write_fixture_plist(daemon_path, daemon_fixture.merge("ProcessType" => "Background"))
    expect_failure("obsolete helper scheduling class") { validate(rc_base.merge(bundle: bundle)) }
    write_fixture_plist(daemon_path, daemon_fixture)
    expect_equal(accepted_rc.fetch("releaseLabel"), "1.0.0-rc.4", "validated RC label")
    expect_equal(accepted_rc.fetch("version"), "1.0.0", "RC numeric marketing version")
    expect_equal(accepted_rc.fetch("hardwareValidation"), "pending", "validated RC hardware status")
    puts "self-test accepted RC metadata with a numeric bundle version"

    wrong_asset_url = "https://github.com/Marios1111/lidpilot/releases/download/v1.0.0/LidPilot-1.0.0.zip"
    expect_failure("RC metadata with a stable immutable URL") do
      validate(rc_base.merge(download_url: wrong_asset_url))
    end
    expect_failure("RC metadata marked hardware approved") do
      validate(rc_base.merge(hardware_validation: "approved"))
    end
    expect_failure("RC label embedded as bundle marketing version") do
      app_info = File.join(bundle, "Contents", "Info.plist")
      info = read_plist(app_info, "fixture Info.plist")
      info["CFBundleShortVersionString"] = "1.0.0-rc.4"
      write_fixture_plist(app_info, info)
      validate(rc_base.merge(bundle: bundle))
    end
    expect_failure("release-notes origin mismatch") do
      wrong_notes = File.read(rc_appcast).sub("https://lidpilot.app/rc/LidPilot-1.0.0-rc.4.md", "https://other.github.io/lidpilot/rc/LidPilot-1.0.0-rc.4.md")
      File.write(rc_appcast, wrong_notes)
      validate(rc_base)
    end
    File.write(rc_appcast, File.read(rc_appcast).sub("https://other.github.io/lidpilot/rc/LidPilot-1.0.0-rc.4.md", "https://lidpilot.app/rc/LidPilot-1.0.0-rc.4.md"))
    expect_failure("appcast enclosure URL mismatch") do
      wrong_asset = File.read(rc_appcast).sub(rc_config.fetch("downloadURL"), wrong_asset_url)
      File.write(rc_appcast, wrong_asset)
      validate(rc_base)
    end
    File.write(rc_appcast, File.read(rc_appcast).sub(wrong_asset_url, rc_config.fetch("downloadURL")))
    expect_failure("invalid stable label") do
      validate(stable_base.merge(release_label: "1.0.0-rc.4"))
    end
    expect_failure("wrong archive filename") do
      validate(rc_base.merge(archive: archive))
    end
    expect_failure("missing application bundle paths") do
      empty_bundle = File.join(dir, "Missing.app")
      FileUtils.mkdir_p(File.join(empty_bundle, "Contents"))
      validate(rc_base.merge(bundle: empty_bundle))
    end
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
  opts.on("--release-label LABEL") { |value| options[:release_label] = value }
  opts.on("--channel CHANNEL") { |value| options[:channel] = value }
  opts.on("--build BUILD") { |value| options[:build] = value }
  opts.on("--hardware-validation STATUS") { |value| options[:hardware_validation] = value }
  opts.on("--state-file PATH") { |value| options[:state_file] = value }
  opts.on("--resolve-config") { options[:resolve_config] = true }
  opts.on("--check-monotonic-build") { options[:check_monotonic_build] = true }
  opts.on("--team TEAM") { |value| options[:team] = value }
  opts.on("--sign-tool PATH") { |value| options[:sign_tool] = value }
  opts.on("--private-key-file PATH") { |value| options[:private_key_file] = value }
  opts.on("--self-test") { options[:self_test] = true }
end

begin
  parser.parse!(ARGV)
  if options[:self_test]
    self_test
  elsif options[:resolve_config]
    fail_validation("missing --version") unless options[:version]
    puts JSON.generate(release_configuration(options[:version]))
  elsif options[:check_monotonic_build]
    fail_validation("missing --build") unless options[:build]
    fail_validation("missing --state-file") unless options[:state_file]
    check_monotonic_build_file(options[:build], options[:state_file])
    puts "build number is strictly monotonic"
  else
    %i[archive appcast notes feed_url download_url repository version release_label channel build hardware_validation].each do |key|
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
