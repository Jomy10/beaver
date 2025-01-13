require_relative 'build-utils.rb'

default_version = "3.4"

mode = nil
name = nil
path = nil
arg = ARGV[0]

case arg
when "help"
  puts "Usage: ruby #{$file} [command] [arg]"
  puts "Commands:"
  puts "  pkgconfig (default): look for ruby version with pkg-config. Requires ruby-<version>.pc to be findable by pkg-config. Argument expects a version (default: #{default_version})"
  puts "  rvm: use a version known by rvm. Argument expects a version (default: #{default_version})"
  puts "  xcode: use macOS default ruby version"
  puts "  rbenv: use a version known by rbenv. Arg must be a version (default: #{default_version})"
  puts "  custom: argument must be path pointing to a ruby installation"
  exit(0)
when "xcode"
  mode = arg
when "rbenv"
  mode = arg
  name = ARGV[1] || default_version
when "pkgconfig", "rvm"
  mode = arg
  name = ARGV[1] || "ruby-#{default_version}"
when "custom"
  mode = arg
  path = ARGV[1]
  if path == nil
    raise "mode 'custom' requires an extra argument pointing to the ruby installation"
  end
else
  mode = "pkgconfig"
  name = "ruby-#{arg || default_version}"
end

# Configure ruby version
sh "swift package update"
sh "swift package edit CRuby", onError: :return
sh "Packages/CRuby/cfg-cruby --mode #{mode} #{name == nil ? "" : "--name #{name}"} #{path == nil ? "" : "--path #{path}"}"

File.read("")
