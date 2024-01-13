require 'fileutils'
require 'pathname'

module Beaver
  # Returns a list of files expanded from the fileexpression(s)
  def self.eval_filelist(filelist)
    if filelist.nil? then return nil end
    
    if filelist.is_a? String
      return Dir[filelist]
    elsif filelist.respond_to? :each
      return filelist.flat_map { |expr|
        if expr.nil?
          Beaver::Log::err("Found nil in file list #{filelist.inspect}")
        else
          Dir[expr]
        end
      }
    else
      Beaver::Log::err("Invalid filelist #{filelist.describe}")
    end
  end
  
  def self.def_dir(dir_name)
    if !Dir.exist? dir_name
      FileUtils.mkdir_p(dir_name)
    end
  end
end

