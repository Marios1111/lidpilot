#!/usr/bin/env ruby
# frozen_string_literal: true

require "digest"
require "json"
require "open3"
require "rbconfig"
require "tmpdir"

GENERATOR = "scripts/generate_homebrew_cask.rb"

def assert(condition, message)
  raise message unless condition
end

def generator_result(manifest_path:, dmg_path:, download_url:, output_path: nil)
  command = [RbConfig.ruby, GENERATOR, "--manifest", manifest_path, "--dmg", dmg_path, "--download-url", download_url]
  command.concat(["--output", output_path]) if output_path
  Open3.capture3(*command)
end

def assert_rejected(description)
  stdout, stderr, status = yield
  raise "expected rejection: #{description}" if status.success?
  raise "missing useful error for #{description}" if stdout.empty? && stderr.empty?
end

Dir.mktmpdir("lidpilot-homebrew-test-") do |directory|
  version = "9.8.7"
  filename = "LidPilot-#{version}.dmg"
  dmg_path = File.join(directory, filename)
  File.binwrite(dmg_path, "synthetic signed DMG fixture\n")
  digest = Digest::SHA256.file(dmg_path).hexdigest
  manifest_path = File.join(directory, "manifest.json")
  manifest = {
    "version" => version,
    "releaseLabel" => version,
    "channel" => "stable",
    "hardwareValidation" => "approved",
    "profilingEnabled" => false,
    "build" => "987",
    "feedURL" => "https://lidpilot.app/updates/appcast.xml",
    "downloadURL" => "https://github.com/Marios1111/lidpilot/releases/download/v#{version}/LidPilot-#{version}.zip",
    "files" => [
      { "name" => "dmg", "path" => filename, "sha256" => digest },
      { "name" => "update-archive", "path" => "LidPilot-#{version}.zip", "sha256" => "a" * 64 }
    ]
  }
  File.write(manifest_path, JSON.pretty_generate(manifest))
  download_url = "https://github.com/Marios1111/lidpilot/releases/download/v#{version}/#{filename}"

  stdout, stderr, status = generator_result(manifest_path: manifest_path, dmg_path: dmg_path, download_url: download_url)
  assert(status.success?, "valid stable manifest should generate a cask: #{stderr}")
  output = stdout
  assert(output.include?("cask \"lidpilot\" do"), "generated cask token")
  assert(output.include?("version \"#{version}\""), "generated stable version")
  assert(output.include?("sha256 \"#{digest}\""), "generated verified DMG checksum")
  assert(output.include?("url \"#{download_url}\""), "generated immutable DMG URL")
  assert(output.include?("auto_updates true"), "Sparkle-owned update declaration")
  assert(output.include?("depends_on arch: :arm64"), "Apple Silicon requirement")
  assert(output.include?("depends_on macos: :sequoia"), "macOS 15 requirement")
  assert(output.include?("app \"LidPilot.app\""), "app bundle artifact")
  assert(!output.match?(/uninstall_preflight|launchctl|sudo|\bscript:/), "no private hooks or privileged cleanup bypass")

  syntax_output, syntax_error, syntax_status = Open3.capture3(RbConfig.ruby, "-c", stdin_data: output)
  assert(syntax_status.success? && syntax_output.include?("Syntax OK"), "generated cask must parse as Ruby: #{syntax_error}")

  File.write(manifest_path, JSON.pretty_generate(manifest.merge("repository" => "Marios1111/lidpilot")))
  _stdout, stderr, status = generator_result(manifest_path: manifest_path, dmg_path: dmg_path, download_url: download_url)
  assert(status.success?, "manifest repository matching its download URL should be accepted: #{stderr}")
  File.write(manifest_path, JSON.pretty_generate(manifest))

  cask_path = File.join(directory, "lidpilot.rb")
  _stdout, stderr, status = generator_result(manifest_path: manifest_path, dmg_path: dmg_path, download_url: download_url, output_path: cask_path)
  assert(status.success?, "valid cask should write a new output file: #{stderr}")
  assert(File.read(cask_path) == output, "file output must match standard output")
  _stdout, _stderr, status = generator_result(manifest_path: manifest_path, dmg_path: dmg_path, download_url: download_url, output_path: cask_path)
  assert(!status.success?, "generator must refuse to overwrite an existing cask")

  assert_rejected("RC release manifest") do
    File.write(manifest_path, JSON.pretty_generate(manifest.merge("channel" => "rc", "releaseLabel" => "#{version}-rc.1")))
    generator_result(manifest_path: manifest_path, dmg_path: dmg_path, download_url: download_url)
  end

  assert_rejected("profile-enabled stable build") do
    File.write(manifest_path, JSON.pretty_generate(manifest.merge("profilingEnabled" => true)))
    generator_result(manifest_path: manifest_path, dmg_path: dmg_path, download_url: download_url)
  end

  assert_rejected("unapproved hardware validation") do
    File.write(manifest_path, JSON.pretty_generate(manifest.merge("hardwareValidation" => "pending")))
    generator_result(manifest_path: manifest_path, dmg_path: dmg_path, download_url: download_url)
  end

  assert_rejected("repository field conflicts with the GitHub URL") do
    File.write(manifest_path, JSON.pretty_generate(manifest.merge("repository" => "ExampleOwner/lidpilot")))
    generator_result(manifest_path: manifest_path, dmg_path: dmg_path, download_url: download_url)
  end

  assert_rejected("foreign GitHub repository") do
    foreign_manifest = manifest.merge("downloadURL" => manifest.fetch("downloadURL").sub("Marios1111", "ExampleOwner"))
    File.write(manifest_path, JSON.pretty_generate(foreign_manifest))
    foreign_url = download_url.sub("Marios1111", "ExampleOwner")
    generator_result(manifest_path: manifest_path, dmg_path: dmg_path, download_url: foreign_url)
  end

  assert_rejected("manifest checksum mismatch") do
    File.write(manifest_path, JSON.pretty_generate(manifest.merge("files" => [manifest.fetch("files").first.merge("sha256" => "b" * 64)])))
    generator_result(manifest_path: manifest_path, dmg_path: dmg_path, download_url: download_url)
  end

  assert_rejected("non-versioned or mismatched GitHub URL") do
    File.write(manifest_path, JSON.pretty_generate(manifest))
    generator_result(manifest_path: manifest_path, dmg_path: dmg_path, download_url: "https://github.com/Marios1111/lidpilot/releases/latest/download/#{filename}")
  end

  assert_rejected("URL with query string") do
    generator_result(manifest_path: manifest_path, dmg_path: dmg_path, download_url: "#{download_url}?download=1")
  end

  assert_rejected("malformed release manifest") do
    File.write(manifest_path, "{\"version\":")
    generator_result(manifest_path: manifest_path, dmg_path: dmg_path, download_url: download_url)
  end

  assert_rejected("DMG bytes changed after manifest creation") do
    File.write(manifest_path, JSON.pretty_generate(manifest))
    File.binwrite(dmg_path, "changed bytes\n")
    generator_result(manifest_path: manifest_path, dmg_path: dmg_path, download_url: download_url)
  end

  assert_rejected("DMG filename does not match manifest version") do
    wrong_dmg = File.join(directory, "LidPilot-9.8.6.dmg")
    File.binwrite(wrong_dmg, "synthetic signed DMG fixture\n")
    generator_result(manifest_path: manifest_path, dmg_path: wrong_dmg, download_url: download_url)
  end

  puts "Homebrew cask generator tests passed"
end
