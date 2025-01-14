include Beaver

# Tries to require a gem, returns false if it could not be found
def try_require(gem)
  begin
    require gem
  rescue LoadError
    return false
  end
end

# TODO: `sh` command that redirects to swift
