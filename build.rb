require_relative 'build-utils.rb'

command = "build"
mode = :debug
argv = ARGV

if argv[0] == "clean"
  sh "cargo clean"
  sh "swift package clean"
  exit(0)
end

if ["build", "test", "package", "run", "repl", "--version", "--help", "help"].include? argv[0]
  command = argv[0]
  argv.delete_at 0
end

if argv[0] == "release"
  mode = :release
  argv.delete_at 0
elsif argv[0] == "debug"
  mode = :debug
  argv.delete_at 0
end

mode_flag = "-c #{mode} "
if command != "build" && command != "run" && command != "test"
  mode_flag = ""
end

## BUILD ##

sh "cargo build #{mode == :release ? "--release" : ""}"

sh "swift #{command} #{mode_flag}#{argv.size == 0 ? "" : argv.join(" ") + " " }-Xlinker -Ltarget/#{mode} -Xlinker -lprogress_indicators",
    envPrepend: { "PKG_CONFIG_PATH" => File.join(Dir.pwd, "Packages/CRuby") }
