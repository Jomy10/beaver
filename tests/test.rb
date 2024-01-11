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

clean_all

require_relative 'basic-c-commands/test.rb'
require_relative 'basic-c-project/test.rb'

Minitest.after_run {
  clean_all
}

