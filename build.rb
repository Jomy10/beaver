def try_require(gem)
  if Gem::Specification.find_by_name(gem)
    require gem
    return true
  else
    return false
  end
end

$color = try_require 'colorize'

def sh(cmd)
  if $color
    puts cmd.grey
  else
    puts cmd
  end

  system cmd

  exit($?.to_i) unless $?.to_i == 0
end

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

sh "swift #{command} #{mode_flag}#{argv.size == 0 ? "" : argv.join(" ") + " " }-Xlinker -Ltarget/#{mode} -Xlinker -lprogress_indicators"
