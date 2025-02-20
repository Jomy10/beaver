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

# Returns true if the file has changed or doesn't exist, false if not
# Will return the or'ed result for all files if multiple files were passed
# nil is returned if no files are passed
def fileChanged(*filename)
  out = nil
  for file in filename
    var = (fileChangedWithContext(file, caller_locations(1, 1).first) || false)
    out ||= var
  end
  return out
end

def __resolveAnyPromise(promise)
  begin
    while !promise.fulfilled?
      sleep(0.1)

      if $BEAVER_ERROR
        exit(300)
      end
    end

    proj = promise.value
    return proj
  ensure
    promise.release
  end
end

class Beaver::SignalOneshot
  def wait
    begin
      while !self.finished?
        sleep(0.1)

        if $BEAVER_ERROR
          exit(300)
        end
      end

      self.check
    ensure
      self.release
    end
  end
end

def project(name)
  promise = projectAsync(name)
  return __resolveAnyPromise(promise)
end

class Beaver::ProjectAccessor
  def run(exeName, *args)
    runAsync(exeName, *args).wait
  end

  def build(targetName)
    puts "building #{targetName}"
    buildAsync(targetName).wait
  end
end

def sh(*args)
  shAsync(*args).wait
end
