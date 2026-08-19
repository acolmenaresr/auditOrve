ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)

auditorve_env = File.expand_path("~/.config/auditorve/env")
if File.exist?(auditorve_env)
  File.foreach(auditorve_env) do |line|
    stripped = line.strip
    next if stripped.empty? || stripped.start_with?("#")

    stripped = stripped.sub(/\Aexport\s+/, "")
    key, value = stripped.split("=", 2)
    next if key.to_s.empty? || value.nil?

    ENV[key.strip] ||= value.strip.gsub(/\A["']|["']\z/, "")
  end
end

require "bundler/setup" # Set up gems listed in the Gemfile.
require "bootsnap/setup" # Speed up boot time by caching expensive operations.
