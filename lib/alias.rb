# Aliases for default ruby commands for easier access by beaver users

# Execute system command
def §(cmd)
  puts cmd
  system cmd
end

# Execute system command
def sys(cmd)
  puts cmd
  system cmd
end

String.prepend(Module.new do
  # The directory a file resides in
  def dirname
    return File.dirname self
  end
  
  # Basename of a file
  def basename
    return File.basename(self, ".*")
  end
  
  # File's basename with extension
  def basename_ext
    return File.basenam self
  end
  
  # The file's extension
  def ext
    return File.extname self
  end
end)
