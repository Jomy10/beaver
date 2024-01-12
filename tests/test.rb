require 'minitest/autorun'
require 'fileutils'

def ignore_exception
  begin
    yield
  rescue Exception
  end
end

def clean
  ignore_exception {
    FileUtils.rm_r ".beaver"
    FileUtils.rm_r "out"
  }
end

def clean_all
  Dir.chdir(__dir__) do
    Dir["*"].select { |f| File.directory?(f) }
      .each do |dir|
        puts "cleaning #{dir}"
        Dir.chdir(dir) do
          clean
        end
      end
  end
end

def self.determine_cmd(*cmds)
  exts = ENV["PATHEXT"] ? ENV["PATHEXT"].split(";") : [""]
  paths = ENV["PATH"].split(File::PATH_SEPARATOR)
  cmds.each do |cmd|
    paths.each do |path|
      exts.each do |ext|
        exe = File.join(path, "#{cmd}#{ext}")
        return exe if File.executable?(exe) && !File.directory?(exe)
      end
    end
  end
end

###############################################################################

clean_all

require_relative 'basic-c-commands/test.rb'
require_relative 'basic-c-project/test.rb'
require_relative 'multi-project/test.rb'
if `uname`.include?("Darwin") || !(determine_cmd("gnustep-conig").nil?)
  require_relative 'objc-project/test.rb'
else
  STDERR.puts "Cannot run objc test: no Objective-C compiler installed"
end

Minitest.after_run {
  clean_all
}

