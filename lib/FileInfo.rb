require 'json'
require 'fileutils'

# date: last modified
FileInfo = Struct.new(:date)

class FileInfoRW 
  # file_loc = cache file location
  # file_path = path of the file that represents the cache file
  def initialize(file_loc, file_path)
    @file_loc = file_loc
    @file_path = file_path
  end
  
  # Read the info file and write a new one if needed
  # Report back if the file has changed
  def file_has_changed?()
    cache_file = File.open(@file_loc)
    
    file_info = JSON.parse(cache_file.read, object_class: OpenStruct)
    last_modified = File.mtime(@file_path).to_i
    if last_modified > file_info.date
      json = self._json
      File.write(@file_loc, json)
      return true
    else
      return false
    end
  end
  
  # Create the cache file
  def create_cache()
    json = self._json

    dirnames = File.dirname(@file_loc)
    unless File.directory?(dirnames)
      # Directories do not exist, create them
      FileUtils.mkdir_p(dirnames)
    end
    
    File.write(@file_loc, json)
  end
  
  private
  # FileInfo as json
  def _json
    return FileInfo.new(
      File.mtime(@file_path).to_i
    ).to_h.to_json
  end
end
