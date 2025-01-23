include Beaver

# Tries to require a gem, returns false if it could not be found
def try_require(gem)
  begin
    require gem
  rescue LoadError
    return false
  end
end

# Dependency = Struct.new(:target, :project, :artifact)
DependencyResolve = Struct.new(:inner, :artifact)

def static(inner)
  return DependencyResolve.new(inner, :staticlib)
end

def dynamic(inner)
  return DependencyResolve.new(inner, :dynlib)
end

# Returns true if the file has changed, false if not and nil if the file doesn't exist
def fileChanged(filename)
  fileChangedWithContext(filename, caller_locations(1, 1).first)
end

# TODO: `sh` command that redirects to swift
