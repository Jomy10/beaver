module C
  module Internal
    Target = Struct.new(
      # [String]
      :name,
      # [String[] | String]
      :sources,
      # [String | String[] | Object]
      :include,
      # [String | String[]]
      :cflags,
      # [String | String[]]
      :ldflags,
      # [Library[]]
      :dependencies,
      # Optionally add this to another project
      # Will always be initialized
      # [String]
      :project,
      :_type,
      keyword_init: true
    ) do 
      def _cflags
        if self.cflags.nil? then return nil end
        return (self.cflags.is_a? String) ? self.cflags : self.cflags.join(" ")
      end

      def _include_flags
        if self.include.nil? then return nil end
        return Target._parse_include(self.include)
      end

      def _public_include_flags
        if self.include.nil? then return nil end
        return Target._parse_public_include(self.include)
      end

      # recursively search for dependencies
      def _all_system_deps
        if self.dependencies.nil? then return nil end
        deps = []
        for dependency_name in self.dependencies
          dependency = self.project.get_target(dependency_name)
          if dependency.type == LibraryType::SYSTEM
            deps << dependency
          end
          sub_dependencies = dependency._all_system_deps
          if !sub_dependencies.nil?
              deps.push(*sub_dependencies)
          end
        end
        return deps.uniq
      end

      # TODO: args -> quoted
      def _build_obj
        obj_dir = File.join(self.project.build_dir, self.name, "obj")
        Beaver::def_dir(obj_dir)
        cflags = self._cflags || ""
        cflags << " " + self.project.cflags
        cflags.strip!
        include_flags = self._include_flags || ""
        include_flags << " " + self.project.include_flags
        include_flags.strip!

        # system_deps = self._all_system_deps
        # if !system_deps.nil?
        #   for dependency in self._all_system_deps
        #     dep_cflags = dependency._cflags
        #     dep_include_flags = dependency._public_include_flags
        #     if !dep_cflags.nil?
        #       cflags << (" " + dep_cflags)
        #     end
        #     if !dep_include_flags.nil?
        #       include_flags << (" " + dep_include_flags)
        #     end
        #   end
        # end

        for file in Beaver::eval_filelist(self.sources)
          puts "clang" + " " + # TODO
            "-c #{file}" + " " +
            cflags + " " +
            include_flags + " " +
            "-o " + File.join(obj_dir, file.gsub("/", "_") + ".o")
        end
      end
      
      def _buid_exe
        
      end

      private
      # Include can be of type:
      # - String
      # - String[]
      # - { :internal => String | String[], :public => String | String[] }
      def self._parse_include(include)
        if include.is_a? String
          return "-I#{include}"
        elsif include.is_a? Hash
          return include.map { |k, v| Target._parse_include(v) }.join(" ")
        elsif include.respond_to? :each
          return include.map { |folder| "-I#{folder} " }.join(" ")
        else
          Beaver::Log::err("Invalid include #{include.describe}")
        end
      end

      def self._parse_public_include(include)
        if include.is_a? String
          return "-I#{include}"
        elsif include.is_a? Hash
          return Target._parse_public_include(include[:public])
        elsif include.respond_to? :each
          return include.map { |folder| "-I#{folder} " }.join(" ")
        else
          Beaver::Log::err("Invalid include #{include.describe}")
        end
      end
    end
  end

  module LibraryType
    USER = 0
    SYSTEM = 1
  end

  class Library < Internal::Target
    include Beaver::Internal::PostInitable
    include Beaver::Internal::TargetPostInit

    def type
      if self._type.nil?
        return LibraryType::USER
      else
        return self._type
      end
    end

    # Create a new system library
    # @param name [String] the name of the system library
    def self.system(name, system_name: nil, cflags: nil, ldflags: nil)
      _ldflags = ["-l#{system_name || name}"]
      if !ldflags.nil?
        if ldflags.respond_to? :each
          _ldflags.push(*ldflags)
        else
          _ldflags << ldflags
        end
      end
      return Library.new(
        name: name,
        _type: LibraryType::SYSTEM,
        cflags: cflags,
        ldflags: _ldflags
      )
    end

    # Create a new system library defined by pkg-config
    # @param name [String] the name of the pkg_config module
    # @param pkg_config_name [String] the name of the package config package, default is `name` 
    def self.pkg_config(name, pkg_config_name: nil)
      # TODO: error handling
      return Library.new(
        name: name,
        _type: LibraryType::SYSTEM,
        cflags:  `pkg-config #{pkg_config_name || name} --cflags`.gsub("\n", ""),
        ldflags: `pkg-config #{pkg_config_name || name} --libs`.gsub("\n", "")
      )
    end
  end

  class Executable < Internal::Target
    include Beaver::Internal::PostInitable
    include Beaver::Internal::TargetPostInit
  end
end

