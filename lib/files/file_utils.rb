require 'fileutils'
require 'pathname'

module Beaver
  # Returns a list of files expanded from the fileexpression(s)
  def self.eval_filelist(filelist, basedir)
    if filelist.nil? then return nil end
    
    filelist = if basedir.nil?
      filelist
    else
      if filelist.is_a? String
        Beaver::safe_join(basedir, filelist)
      elsif filelist.respond_to? :each
        filelist.map { |expr| Beaver::safe_join(basedir, expr) }
      else
        Beaver::Log::err("Invalid filelist #{filelist.describe}")
      end
    end
    
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

  # Join relative and absolute paths together (e.g. the smart version of File.join)
  def self.safe_join(*paths)
    base = paths[0]
    paths[1..].reduce(base) do |acc, path|
      if path.start_with? File::SEPARATOR
        File.join(acc, Pathname.new(path).relative_path_from(acc))
      else
        File.join(acc, path)
      end
    end
  end
end

