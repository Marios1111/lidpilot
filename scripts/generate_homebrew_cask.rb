#!/usr/bin/env ruby
# frozen_string_literal: true

require "digest"
require "json"
require "optparse"
require "uri"

module HomebrewCaskGenerator
  module_function

  class ValidationError < StandardError; end

  VERSION_PATTERN = /\A(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\z/
  SHA256_PATTERN = /\A[a-f0-9]{64}\z/
  REPOSITORY_PATTERN = /\A[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+\z/
  EXPECTED_REPOSITORY = "Marios1111/lidpilot"
  STABLE_FEED_URL = "https://lidpilot.app/updates/appcast.xml"
  HOMEPAGE_URL = "https://lidpilot.app/"

  def generate(manifest_path:, dmg_path:, download_url:)
    manifest = read_manifest(manifest_path)
    release = validate_manifest(manifest)
    validate_dmg(dmg_path, release)
    validate_download_url(download_url, release)

    render_cask(
      version: release.fetch(:version),
      sha256: release.fetch(:sha256),
      download_url: download_url
    )
  end

  def read_manifest(path)
    JSON.parse(File.read(path))
  rescue Errno::ENOENT, Errno::EACCES => e
    raise ValidationError, "cannot read release manifest: #{e.message}"
  rescue JSON::ParserError => e
    raise ValidationError, "release manifest is not valid JSON: #{e.message}"
  end

  def validate_manifest(manifest)
    fail_validation("release manifest must be a JSON object") unless manifest.is_a?(Hash)

    version = manifest["version"]
    fail_validation("release manifest version must be numeric major.minor.patch") unless version.is_a?(String) && VERSION_PATTERN.match?(version)
    fail_validation("Homebrew casks require a stable release manifest") unless manifest["channel"] == "stable"
    fail_validation("stable release label must equal the numeric version") unless manifest["releaseLabel"] == version
    fail_validation("stable manifest must record approved hardware validation") unless manifest["hardwareValidation"] == "approved"
    fail_validation("profile-enabled builds cannot be distributed through Homebrew") unless manifest["profilingEnabled"] == false

    build = manifest["build"]
    fail_validation("release manifest build must be a positive integer") unless build.to_s.match?(/\A[1-9]\d*\z/)
    fail_validation("release manifest must point to the stable Sparkle feed") unless manifest["feedURL"] == STABLE_FEED_URL

    repository = repository_from_update_url(manifest["downloadURL"], version)
    fail_validation("manifest GitHub URL must use #{EXPECTED_REPOSITORY}") unless repository == EXPECTED_REPOSITORY
    if manifest.key?("repository") && manifest["repository"] != repository
      fail_validation("manifest repository must match its GitHub downloadURL")
    end

    entries = manifest["files"]
    fail_validation("release manifest files must be an array") unless entries.is_a?(Array)
    dmg_entries = entries.select { |entry| entry.is_a?(Hash) && entry["name"] == "dmg" }
    fail_validation("release manifest must contain exactly one DMG entry") unless dmg_entries.length == 1

    dmg = dmg_entries.first
    filename = "LidPilot-#{version}.dmg"
    fail_validation("manifest DMG path must be the versioned release filename") unless dmg["path"] == filename
    digest = dmg["sha256"]
    fail_validation("manifest DMG SHA-256 must contain 64 lowercase hexadecimal characters") unless digest.is_a?(String) && SHA256_PATTERN.match?(digest)

    {
      version: version,
      repository: repository,
      filename: filename,
      sha256: digest
    }
  end

  def repository_from_update_url(value, version)
    fail_validation("manifest update downloadURL must be a string") unless value.is_a?(String)

    match = %r{\Ahttps://github\.com/([A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+)/releases/download/v#{Regexp.escape(version)}/LidPilot-#{Regexp.escape(version)}\.zip\z}.match(value)
    fail_validation("manifest update downloadURL must be the immutable versioned GitHub ZIP URL") unless match
    repository = match[1]
    fail_validation("manifest repository format is invalid") unless REPOSITORY_PATTERN.match?(repository)
    repository
  end

  def validate_dmg(path, release)
    begin
      stat = File.lstat(path)
    rescue Errno::ENOENT, Errno::EACCES => e
      fail_validation("cannot inspect final DMG: #{e.message}")
    end
    fail_validation("final DMG must be a regular, non-symlink file") unless stat.file? && !stat.symlink?
    fail_validation("final DMG filename does not match the stable version") unless File.basename(path) == release.fetch(:filename)

    digest = Digest::SHA256.file(path).hexdigest
    fail_validation("final DMG SHA-256 does not match the release manifest") unless digest == release.fetch(:sha256)
  rescue SystemCallError => e
    fail_validation("cannot hash final DMG: #{e.message}")
  end

  def validate_download_url(value, release)
    fail_validation("DMG download URL must be a string") unless value.is_a?(String)

    uri = URI.parse(value)
    fail_validation("DMG download URL must use HTTPS") unless uri.is_a?(URI::HTTPS)
    fail_validation("DMG download URL must use github.com") unless uri.host == "github.com"
    fail_validation("DMG download URL must not contain credentials, a query, or a fragment") if uri.userinfo || uri.query || uri.fragment

    expected = "https://github.com/#{release.fetch(:repository)}/releases/download/v#{release.fetch(:version)}/#{release.fetch(:filename)}"
    fail_validation("DMG download URL must match the versioned GitHub release asset URL") unless value == expected
  rescue URI::InvalidURIError => e
    fail_validation("DMG download URL is invalid: #{e.message}")
  end

  def render_cask(version:, sha256:, download_url:)
    <<~CASK
      cask "lidpilot" do
        version "#{version}"
        sha256 "#{sha256}"

        url "#{download_url}"
        name "LidPilot"
        desc "Control bounded keep-awake sessions from the menu bar"
        homepage "#{HOMEPAGE_URL}"

        auto_updates true
        depends_on arch: :arm64
        depends_on macos: :sequoia

        app "LidPilot.app"

        caveats <<~EOS
          Before Homebrew removes or replaces LidPilot, use the app to confirm Turn Off,
          disable Launch at login, remove the helper in Settings → Helper & Recovery,
          wait for LidPilot to confirm removal, then quit normally. Removing the app
          directly through Homebrew without this cleanup is unsupported.
        EOS
      end
    CASK
  end

  def fail_validation(message)
    raise ValidationError, message
  end
end

if $PROGRAM_NAME == __FILE__
  options = {}
  parser = OptionParser.new do |opts|
    opts.banner = "Usage: ruby scripts/generate_homebrew_cask.rb --manifest PATH --dmg PATH --download-url URL [--output PATH]"
    opts.on("--manifest PATH", "Final stable release manifest.json") { |value| options[:manifest] = value }
    opts.on("--dmg PATH", "Local final DMG whose bytes match the manifest") { |value| options[:dmg] = value }
    opts.on("--download-url URL", "Exact versioned GitHub Release DMG asset URL") { |value| options[:download_url] = value }
    opts.on("--output PATH", "Write a new cask file (refuses to overwrite)") { |value| options[:output] = value }
    opts.on("-h", "--help", "Show this help") do
      puts opts
      exit 0
    end
  end

  begin
    parser.parse!
    missing = %i[manifest dmg download_url].reject { |key| options.key?(key) }
    raise HomebrewCaskGenerator::ValidationError, "missing required options: #{missing.map { |key| "--#{key.to_s.tr("_", "-")}" }.join(", ")}" unless missing.empty?

    cask = HomebrewCaskGenerator.generate(
      manifest_path: options.fetch(:manifest),
      dmg_path: options.fetch(:dmg),
      download_url: options.fetch(:download_url)
    )

    if options[:output]
      File.open(options.fetch(:output), File::WRONLY | File::CREAT | File::EXCL, 0o644) { |file| file.write(cask) }
      puts "wrote #{options.fetch(:output)}"
    else
      print cask
    end
  rescue OptionParser::ParseError, HomebrewCaskGenerator::ValidationError, SystemCallError => e
    warn "Homebrew cask generation failed: #{e.message}"
    exit 1
  end
end
