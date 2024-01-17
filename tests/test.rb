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

def windows?
  (/cygwin|mswin|mingw|bccwin|wince|emx/ =~ RUBY_PLATFORM) || ENV["OS"] == "Windows_NT"
end

def linux?
  /linux/ =~ RUBY_PLATFORM
end

def macos?
  /darwin/ =~ RUBY_PLATFORM
end

def freebsd?
  /freebsd/ =~ RUBY_PLATFORM
end

# Language-specific tests: are only tested on the following platforms
def objc?
  macos? || (linux? && determine_cmd("gnustep-config"))
end

def swift?
  macos? || linux?
end

###############################################################################

clean_all

require_relative 'basic-c-commands/test.rb'
require_relative 'basic-c-project/test.rb'
require_relative 'multi-project/test.rb'
require_relative 'multi-project-different-file/test.rb'
require_relative 'objc-project/test.rb'
require_relative 'swift-project/test.rb'

Minitest.after_run {
  clean_all
  if swift?
    Dir.chdir(File.join(__dir__, "swift-project", "TestPackage")) do
      system "swift package clean"
    end
  end
}

