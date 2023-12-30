require 'fileutils'

module Beaver
  # Returns a list of files expanded from the fileexpression(s)
  def self.eval_filelist(filelist)
    if filelist.nil? then return nil end

    if filelist.is_a? String
      return Dir[filelist]
    elsif filelist.respond_to? :each
      return filelist.flat_map { |expr| Dir[expr] }
    else
      Beaver::Logger::err("Invalid filelist #{filelist.describe}")
    end
  end

  def self.def_dir(dir_name)
    if !Dir.exists? dir_name
      FileUtils.mkdir_p(dir_name)
    end
  end
end

