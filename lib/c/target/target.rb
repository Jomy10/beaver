# TODO: args -> quoted

module C
  module Internal
    class Target < Struct.new(
      # [String]
      :name,
      # [String]
      :description,
      :homepage,
      :version,
      # [String[] | String]
      :sources,
      # [String[] | String | Object]
      :include,
      # [String[] | String | Object]
      :cflags,
      # [String[] | String | Object]
      :ldflags,
      # [Library[]]
      :dependencies,
      # Optionally add this to another project
      # Will always be initialized
      # [String]
      :project,
      # [String] Either "C", "C++" or "Mixed"
      :language,
      
      # Library-specific #
      # Valid values are: :static, :dynamic
      # [Symbol | Symbol[]] (or anything that converts into a symbol)
      :type,
      # For pkg-config file
      :conflicts,
      :_library_type,
      keyword_init: true
    ) 
      include Beaver::Internal::PostInitable
      include Beaver::Internal::Target
      
      # Directories #
      def out_dir
        # TODO: add extra path for os/arch inside of project
        Beaver::safe_join(self.project.build_dir, self.name)
      end
      
      def abs_out_dir
        Beaver::safe_join(self.project.base_dir, self.out_dir)
      end
      
      def obj_dir
        Beaver::safe_join(self.abs_out_dir, "obj")
      end
      
      # Flags #
      # TODO: filter duplicate flags
      def private_cflags
        if @__private_cflags.nil?
          @__private_cflags = Target._parse_private_flags(self.cflags) || []
        end
        return @__private_cflags
      end
      
      def public_cflags
        if @__public_cflags.nil?
          @__public_cflags = []
          flags = Target._parse_public_flags(self.cflags)
          if !flags.nil? then @__public_cflags.push(*flags) end
          
          self.dependencies.each do |dep|
            target = self.project.get_target(dep.name)
            @__public_cflags.push(*target.public_cflags)
          end
        end
        
        return @__public_cflags
      end
      
      def private_includes
        if @__private_includes.nil?
          @__private_includes = Target._parse_private_flags(self.include) || []
        end
        return @__private_includes
      end
      
      # returns the directories
      def public_includes
        if @__public_includes.nil?
          @__public_includes = []
          flags = Target._parse_public_flags(self.include)
          if !flags.nil? then @__public_includes.push(*flags) end
          
          self.dependencies.each do |dep|
            target = self.project.get_target(dep.name)
            @__public_includes.push(*target.public_includes)
          end
        end

        return @__public_includes
      end

      # LDFLAGS of this library and all its dependencies
      def public_ldflags
        if @__public_ldflags.nil?
          @__public_ldflags = []
          flags = Target._parse_public_flags(self.ldflags)
          if !flags.nil? then @__public_ldflags.push(*flags) end

          self.dependencies.each do |dep|
            target = self.project.get_target(dep.name)
            @__public_ldflags.push(*target.public_ldflags)
            if target.buildable?
              case dep.type
              when :any
                @__public_ldflags.push(*["-L#{target.abs_out_dir}", "-l#{target.name}"])
              when :static
                if !target.is_static?
                  Beaver::Log::err("Cannot statically link dynamic library target #{target.name}")
                end
                tmp_dir = FileUtils.mkdir_p(Beaver::safe_join($beaver.temp_dir, "#{target.name}_static")).first
                FileUtils.cp(target.static_lib_path, tmp_dir)
                @__public_ldflags.push(*["-L#{tmp_dir}", "-l#{target.name}"])
              when :dynmic
                Beaver::Log::warn("Explicitly declaring a dependency as dyamic; the compiler will always pick the dynamic library if available")
                if !target.is_dynamic?
                  Beaver::Log::err("Cannot dynamically link non-dnymaic library target #{target.name}")
                end
                @__public_ldflags.push(*["-L#{target.abs_out_dir}", "-l#{target.name}"])
              end
            end
          end
        end
        
        return @__public_ldflags
      end
      
      # Tools #
      def get_cc
        cc = if self.language == "C" || self.language.nil?
          $beaver.get_tool(:cc)
        elsif self.language == "C++"
          $beaver.get_tool(:cxx)
        elsif self.language == "Obj-C"
          $beaver.get_tool(:objc_compiler)
        elsif self.language == "Mixed"
          nil
        else
          Beaver::Log::err("Invalid language #{self.language}")
        end
        return cc
      end
      
      # Build #
      def build_dependencies
        Workers.map(self.dependencies) do |dependency|
          target = self.project.get_target(dependency.name)
          Beaver::Log::err("Undefined target #{dependency} in dependencies of target #{self.name}") if target.nil?
          target.build_if_not_built_yet
        end
      end
      
      # Clean all objects and artifacts
      def clean
        FileUtils.rm_r(self.abs_out_dir)
      end
      
      def build_if_not_built_yet
        Beaver::Log::err("Unimplemented")
      end
      
      private
      def _custom_after_init
        # Parse properties
        if self.buildable?
          Beaver::Log::err("Target #{self.name} has no source files defined") if self.sources.nil?
        end
        Beaver::Log::err("Property `type` of C::Target should be of type: Symbol | Symbol[] | nil, or convertible into a symbol (e.g. string)") if !(self.type.nil? || self.type.is_a?(Symbol) || self.type.respond_to?(:each))
        
        if self.language.to_s == "Obj-C"
          if `uname`.include?("Darwin")
            #self.cflags = Target::append_flag(self.cflags, "-fobjc-arc")
          else
            self.cflags = Target::append_flag(self.cflags, `gnustep-config --objc-flags`.gsub("\n", " ").split(" "))
            self.ldflags = Target::append_flag(self.ldflags, `gnustep-config --base-libs`.gsub("\n", " ").split(" "))
          end
        end
        
        self.dependencies = C::Dependency.parse_dependency_list(self.dependencies, self.project.name)
      end
      
      def self.append_flag(flags, flag)
        if flags.nil?
          flag.respond_to?(:each) ? flag : [flag]
        elsif flags.respond_to?(:each)
          flag.respond_to?(:each) ? [*flags, *flag] : [*flags, flag]
        else
          flag.respond_to?(:each) ? [flags, *flag] : [flags, flag]
        end
      end
      
      def self._parse_public_flags(flags)
        if flags.nil? then return nil end
         
        if flags.is_a? String
          return [flags]
        elsif flags.is_a? Array
          return flags
        elsif flags.is_a? Hash
          pub = flags[:public]
          if !pub.nil?
            if pub.is_a? String
              return [pub]
            elsif pub.is_a? Array
              return pub
            else
              Beaver::Log::err("#{pub.inspect}: #{pub.class} is not a valid type for flags in flags object. Valid are: Array, String")
            end
          end
        else
          Beaver::Log::err("#{flags.inspect}: #{flags.class} is not a valid type for flags. Valid are: String, Array, Object containing public and/or private key")
        end
      end
      
      def self._parse_private_flags(flags)
        if flags.nil? then return flags end
        
        if flags.is_a? Hash
          priv = flags[:private]
          if !priv.nil?
            if priv.is_a? String
              return [priv]
            elsif priv.is_a? Array
              return priv
            else
              Beaver::Log::err("#{priv.inspect}: #{priv.class} is not a valid type for flags in flags object. Valid are: Array, String")
            end
          end
        end
      end
      
      # recursively search for dependencies
      def _all_system_deps
        return nil if self.dependencies.nil?
        deps = []
        for dependency in self.dependencies
          dependency = self.project.get_target(dependency.name)
          if LibraryType::is_system?(dependency.library_type)
            deps << dependency
          end
          sub_dependencies = dependency._all_system_deps
          if !sub_dependencies.nil?
              deps.push(*sub_dependencies)
          end
        end
        return deps.uniq
      end
      
      # For Mixed language targets #
      def self._determine_language_for_file(file)
        if file.ext.downcase == ".c"
          return :c
        elsif [".cpp", ".cc", ".cxx"].include? file.ext.downcase
          return :cpp
        elsif [".m", ".mm"].include? file.ext.downcase
          return :objc
        else
          Beaver::Log::err("File extension #{file.ext} is not a valid C/C++/Obj-C file extension")
        end
      end
      
      # Get the compiler based on file extension (for Mixed language targets)
      def self._get_compiler_for_language(lang)
        case lang
        when :c
          $beaver.get_tool(:cc)
        when :cpp
          $beaver.get_tool(:cxx)
        when :objc
          $beaver.get_tool(:objc_compiler)
        else
          Beaver::Log::err("Invalid language #{lang}")
        end
      end
      
      def self._get_compiler_for_file(file)
        Target::_get_compiler_for_language(Target::_determine_language_for_file(file))
      end
      
      def self._get_cflags_for_language(lang)
        case lang
        when :objc
          if `uname`.include?("Darwin")
            #["-fobjc-arc"]
            []
          else
            `gnustep-config --objc-flags`.gsub("\n", "").split(" ")
          end
        else
          []
        end
      end
      
      def self._get_cflags_for_file(file)
        Target::_get_cflags_for_language(Target::_determine_language_for_file(file))
      end
      
      def self._get_ldflags_for_language(lang)
        case lang
        when :objc
          if !(`uname`.include?("Darwin"))
            `gnustep-config --base-libs`.gsub("\n", "").split(" ")
          else
            []
          end
        else
          []
        end
      end
      
      def contains_objc?
        inputs = Beaver::eval_filelist(self.sources, self.project.base_dir)
        return inputs.include?(".m") || inputs.include?(".mm")
      end
    end
  end
end

