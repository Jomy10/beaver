# Executes a function if a file exists, passing in the existing file
def if_exists(files, &func)
  files.each do |file|
    if File.file?(file)
      func.call file
    end
  end
end

# Executes a function if a file does not exists, passing in the non-existing file
def if_not_exists(files, &func)
  files.each do |file|
    unless File.file?(file)
      func.call file
    end
  end
end

# Executes a function if a file exists, passing in the existing file
def unless_exists(files, &func)
  if_not_exists(files, func)
end
