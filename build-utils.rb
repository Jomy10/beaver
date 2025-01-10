def try_require(gem)
  begin
    Gem::Specification.find_by_name(gem)
    require gem
    return true
  rescue
    return false
  end
end

$color = try_require 'colorize'

def sh(cmd, env:nil, envAppend:{}, envPrepend:{}, onError: :exit)
  if $color
    puts cmd.grey
  else
    puts cmd
  end

  _env = nil
  if env != nil
    _env = ENV.merge(env)
  else
    _env = ENV
  end

  for k,v in envAppend
    _env[k] = _env[k] != nil ? _env[k] + ":" + v : v
  end

  for k,v in envPrepend
    _env[k] = _env[k] != nil ? v + ":" + _env[k] : v
  end

  system _env, cmd

  case onError
  when :exit
    exit($?.to_i) unless $?.to_i == 0
  when :raise
    raise $?.to_i
  when :return
    return $?.to_i
  else
    raise "unexpected value for onError: #{onError}"
  end
end
