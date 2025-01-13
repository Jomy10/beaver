require_relative 'build-utils.rb'

command = "build"
mode = :debug
onFinish = nil
argv = ARGV

if argv[0] == "clean"
  sh "cargo clean"
  sh "swift package clean"
  exit(0)
end

if ["build", "test", "package", "run", "repl", "--version", "--help", "help", "install"].include? argv[0]
  command = argv[0]
  argv.delete_at 0
end

if command == "install"
  onFinish = "install"
  command = "build"
end

if argv[0] == "release"
  mode = :release
  argv.delete_at 0
elsif argv[0] == "debug"
  mode = :debug
  argv.delete_at 0
end

if mode == :debug
  if onFinish == "install"
    printf "[#{"WARN".yellow}] installing unoptimized build, continue? [Y/n] "
    answer = gets
    if answer.strip == "n"
      exit(1)
    end
  end
end

mode_flag = "-c #{mode} "
if command != "build" && command != "run" && command != "test"
  mode_flag = ""
end

## BUILD ##

sh "cargo build #{mode == :release ? "--release" : ""}"

sh "swift #{command} #{mode_flag}#{argv.size == 0 ? "" : argv.join(" ") + " " }-Xlinker -Ltarget/#{mode} -Xlinker -lprogress_indicators",
    envPrepend: { "PKG_CONFIG_PATH" => File.join(Dir.pwd, "Packages/CRuby") }

case onFinish
when "install"
  puts "Installing beaver...".blue

  require 'os'

  exe_path = "./.build/#{mode}/beaver#{OS.windows? ? ".exe" : ""}"
  if OS.posix?
    puts "Where to install?"
    puts "[1] /opt/compat"
    puts "[2] /usr/local/bin"
    printf "[1/2] "
    answer = gets.strip
    install_dir = nil
    case answer
    when "1"
      install_dir = "/opt"
    when "2"
      install_dir = "/usr/local/bin"
    else
      puts "Illegal option #{answer}"
      exit(1)
    end
    install_path = File.join(install_dir, "beaver")
    if install_dir == "/opt"
      unless Dir.exist?(install_path)
        sh "sudo mkdir #{install_path}"
        sh "sudo chmod go-w #{install_path}"
      end

      puts "You will need to add the new directory to your PATH:".red
      puts "export PATH=\"$PATH:#{install_path}\""
    end

    sh "#{install_dir == "/opt" ? "sudo" : ""} cp #{exe_path} #{install_path}"
  else
    puts "No automatic installation has been configured for your system"
    puts "Copy #{exe_path} to the executable location for your system"
  end
end
