def get_matches(files)
  # All file patterns to process
  patterns_to_process = []
  
  # Check if array or string
  if files.respond_to? :each
    # is an array
    patterns_to_process = file
  else
    patterns_to_process << files
  end
  
  # Contains all files that match the expressions
  matches = nil
  
  patterns_to_process.each do |pattern|
    if pattern.is_a?(Regexp)
      matches = Find.find("./").grep(pattern)
    else
      # is a string
      matches = Dir.glob(pattern)
    end
  end
  
  return matches
end
