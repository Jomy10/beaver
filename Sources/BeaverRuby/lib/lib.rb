include Beaver

##== General utilities ==##

# Tries to require a gem, returns false if it could not be found
def try_require(gem)
  begin
    require gem
  rescue LoadError
    return false
  end
end

##== Async structures (Promise.swift / SignalOneshot.swift) ==##

BEAVER_SLEEP = 0.1

class Beaver::Promise
  def resolve
    begin
      while !self.fulfilled?
        sleep(BEAVER_SLEEP)

        if $BEAVER_ERROR
          exit(300)
        end
      end

      return self.value
    ensure
      self.release
    end
  end
end

class Beaver::SignalOneshot
  def wait
    begin
      while !self.finished?
        sleep(BEAVER_SLEEP)

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

##== utils.swift ==##

# Build Dir #

def buildDir(dir)
  _buildDirAsyncSync(dir).wait
end

# Cache #

# Returns true if the file has changed or doesn't exist, false if not
# Will return the or'ed result for all files if multiple files were passed
# nil is returned if no files are passed
def fileChanged(*filename)
  out = nil
  promises = []
  for file in filename
    promises << _fileChangedWithContextAsyncAsync(file, caller_locations(1, 1).first)
  end
  for promise in promises
    out ||= promise.resolve
  end
  return out
end

def cache(name, value = :get)
  _cacheAsyncAsync(name, value).resolve
end

# Sh #

def sh(*args)
  _shAsyncSync(*args).wait
end

##== accessors.swift / ProjectAccessor.swift ==##

def project(name)
  return _projectAsyncSync(name).resolve
end

class Beaver::ProjectAccessor
  def run(exeName, *args)
    _runAsyncSync(exeName, *args).wait
  end

  def build(targetName)
    # puts "building #{targetName}"
    _buildAsyncSync(targetName).wait
  end
end

##== Dependencies ==##

DependencyResolve = Struct.new(:inner, :artifact)

def static(inner)
  return DependencyResolve.new(inner, :staticlib)
end

def dynamic(inner)
  return DependencyResolve.new(inner, :dynlib)
end
