require 'file_matches'
require 'FileInfo'

# Execute a function if the specified files have changed since last execution
# Also executes the function if the config file has changed
#
# # Parameters
# - files: either an array of files (or file patterns), or a file pattern as a string or regexp
# - func: the body of the if statement
def if_changed(files, &func)
  matches = get_matches(files)
  
  # Execute for each match if either no cache exists, or
  # if the cache indicates a older file version
  matches.each do |file|
    if file_changed?(file) || __beaver_file_changed?
      func.call file
    end
  end
end

# Executes if any file changed
# The callback receives a list of changed files
def if_any_changed(files, &func)
  changed_files = []
  if_changed files do |file|
      changed_files << file
  end
  
  unless changed_files.empty?
    func.call changed_files
  end
end

# check if a single file has changed
# returns true if it has been changed
def file_changed?(file)
  cache_file_loc = "#{$beaver.cache_loc}/#{file}.info"
  info_rw = FileInfoRW.new(cache_file_loc, file)
  if !File.file?(cache_file_loc)
      # File does not exist, so create it and call the function
      info_rw.create_cache()
      
      return true
  else
    # File exists, so read it
    if info_rw.file_has_changed?
      return true
    else
      return false
    end
  end
end

$__beaver_file = nil
def __beaver_file_changed?
  if $__beaver_file == nil
    $__beaver_file = file_changed?($0)
  end
  
  return $__beaver_file
end
