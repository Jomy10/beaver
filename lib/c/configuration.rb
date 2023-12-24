module C
  ID = "C"

  Configuration = Struct.new(
    :cflags,
    :ldflags,
    :user_data,
    keyword_init: true
  )

  Beaver::Project.class_eval {
    # Set the C config
    def c_configs=(hash)
      for k,v in hash
        if @configurations[k] == nil
          Beaver::Log::warn "Configuration #{k} was not yet defined prior to definig C configuration"
          @configurations[k] = Hash.new
        end
        @configurations[k][C::ID] = v
      end
    end

    # Get the additional cflags from the project
    def cflags
      cflags = ""
      if !self.config.nil?
        c_config = self.config[C::ID]
        if !c_config.nil? && !c_config.cflags.nil?
          cflags << " " + Beaver::Project::_parse_flags(c_config.cflags)
        end
      end
      if !$beaver.options[:cflags].nil?
        cflags << " " + Beaver::Project::_parse_flags(@options[:cflags])
      end
      return cflags.strip
    end

    # Get the additiona ldflags from the project
    def ldflags
      c_config = self.config[C::ID]
      ldflags = ""
      if !c_config.nil? && !c_config.ldflags.nil?
        ldflags << " " + Beaver::Project::_parse_flags(c_config.ldflags)
      end
      if !@options[:ldflags].nil?
        cflags << " " + Beaver::project::_parse_flags(@options[:ldflags])
      end
      return ldflags.strip
    end

    # Unimplemented
    def include_flags
      return ""
    end

    private
    # Transform a flags object (String | String[]) to a string
    def self._parse_flags(flags)
      if flags.respond_to? :each
        return flags.join(" ")
      else
         return flags
      end
    end
  }
end

