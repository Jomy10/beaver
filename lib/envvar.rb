module Beaver
  def env(name, value=true, &modify)
    val = ENV[name.to_s] || value
    if modify.nil?
      case value
      when Integer
        Beaver.const_set(name, val.to_i)
        return
      when true, false
        Beaver.const_set(name, val.downcase == "true")
        return
      end
      Beaver.const_set(name, val)
    else
      Beaver.const_set(name, modify.call(val))
    end
  end
end

