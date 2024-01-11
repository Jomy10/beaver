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
        File.join(self.project.build_dir, self.name)
      end
      
      def obj_dir
        File.join(self.out_dir, "obj")
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
                @__public_ldflags.push(*["-L#{target.out_dir}", "-l#{target.name}"])
              when :static
                if !target.is_static?
                  Beaver::Log::err("Cannot statically link dynamic library target #{target.name}")
                end
                tmp_dir = FileUtils.mkdir_p(File.join($beaver.temp_dir, "#{target.name}_static")).first
                FileUtils.cp(target.static_lib_path, tmp_dir)
                @__public_ldflags.push(*["-L#{tmp_dir}", "-l#{target.name}"])
              when :dynmic
                Beaver::Log::warn("Explicitly declaring a dependency as dyamic; the compiler will always pick the dynamic library if available")
                if !target.is_dynamic?
                  Beaver::Log::err("Cannot dynamically link non-dnymaic library target #{target.name}")
                end
                @__public_ldflags.push(*["-L#{target.out_dir}", "-l#{target.name}"])
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
        FileUtils.rm_r(self.out_dir)
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
            self.cflags = Target::append_flag(self.cflags, "-fobjc-arc")
          else
            self.cflags = Target::append_flag(self.cflags, `gnustep-config --objc-flags`)
            self.ldflags = Target::append_flag(self.ldflags, `gnustep-config --base-libs`)
          end
        end
        
        self.dependencies = C::Dependency.parse_dependency_list(self.dependencies, self.project.name)
      end
      
      def self.append_flag(flags, flag)
        if flags.nil?
          [flag]
        elsif flags.respond_to?(:each)
          [*flags, flag]
        else
          [flags, flag]
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
            ["-fobjc-arc"]
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
      
      def self._get_ldflags_for_file(file)
        Target::_get_ldflags_for_language(Target::_determine_language_for_file(file))
      end
    end
  end
end


# module C
  # module Internal
  #   Target = Struct.new(
  #     # [String]
  #     :name,
  #     # Optional description used in pkg-config
  #     :description,
  #     :homepage,
  #     :version,
  #     :conflicts,
  #     # Valid values are: :static, :dynamic
  #     # [Symbol | Symbol[]]
  #     :type,
  #     # [String[] | String]
  #     :sources,
  #     # [String | String[] | Object]
  #     :include,
  #     # [String | String[]]
  #     :cflags,
  #     # [String | String[]]
  #     :ldflags,
  #     # [Library[]]
  #     :dependencies,
  #     # Optionally add this to another project
  #     # Will always be initialized
  #     # [String]
  #     :project,
  #     # Either "C", "C++" or "Mixed"
  #     :language,
  #     :_type,
  #     keyword_init: true
  #   ) do 
  #     def out_dir
  #       File.join(self.project.build_dir, self.name)
  #     end
  #     
  #     def obj_dir
  #       File.join(self.out_dir, "obj")
  #     end
  #     
  #     def is_dynamic?
  #       return self.type.nil? || (self.type.is_a?(Symbol) && self.type == :dynamic) ||
  #         ((self.type.respond_to? :each) ? self.type.include?(:dynamic) : false)
  #     end
  #     
  #     def is_static?
  #       return self.type.nil? || (self.type.is_a?(Symbol) && self.type == :static) ||
  #         ((self.type.respond_to? :each) ? self.type.include?(:static) : false)
  #     end
  #     
  #     def self._parse_public_flags(flags)
  #       if flags.nil? then return nil end
  #        
  #       if flags.is_a? String
  #         return [flags]
  #       elsif flags.is_a? Array
  #         return flags
  #       elsif flags.is_a? Hash
  #         pub = flags[:public]
  #         if !pub.nil?
  #           if pub.is_a? String
  #             return [pub]
  #           elsif pub.is_a? Array
  #             return pub
  #           else
  #             Beaver::Log::err("#{pub.inspect}: #{pub.class} is not a valid type for flags in flags object. Valid are: Array, String")
  #           end
  #         end
  #       else
  #         Beaver::Log::err("#{flags.inspect}: #{flags.class} is not a valid type for flags. Valid are: String, Array, Object containing public and/or private key")
  #       end
  #     end
  #     
  #     def self._parse_private_flags(flags)
  #       if flags.nil? then return flags end
  #       
  #       if flags.is_a? Hash
  #         priv = flags[:private]
  #         if !priv.nil?
  #           if priv.is_a? String
  #             return [priv]
  #           elsif priv.is_a? Array
  #             return priv
  #           else
  #             Beaver::Log::err("#{priv.inspect}: #{priv.class} is not a valid type for flags in flags object. Valid are: Array, String")
  #           end
  #         end
  #       end
  #     end
  #     
  #     # TODO: to lazy variable?
  #     def private_cflags
  #       return Target._parse_private_flags(self.cflags) || []
  #     end
  #     
  #     def public_cflags
  #       cflags = []
  #       flags = Target._parse_public_flags(self.cflags)
  #       if !flags.nil? then cflags.push(*flags) end
  #       
  #       self.dependencies.each do |dep|
  #         target = self.project.get_target(dep.name)
  #         cflags.push(*target.public_cflags)
  #       end
  #       
  #       return cflags
  #     end
  #     
  #     def private_includes
  #       return Target._parse_private_flags(self.include) || []
  #     end
  #     
  #     # returns the directories
  #     def public_includes
  #       includes = []
  #       flags = Target._parse_public_flags(self.include)
  #       if !flags.nil? then includes.push(*flags) end
  #       
  #       self.dependencies.each do |dep|
  #         target = self.project.get_target(dep.name)
  #         includes.push(*target.public_includes)
  #       end
  #       
  #       return includes
  #     end
  #     
  #     # TODO: rewrite to return array
  #     def _ldflags
  #       ldflags = if self.ldflags.nil?
  #         ""
  #       else
  #         (self.ldflags.is_a? String) ? self.ldflags : self.ldflags.join(" ")
  #       end
  #       if !self.dependencies.nil?
  #         deps = self.dependencies.map { |d| [self.project.get_target(d.name), d.type] }
  #         ldflags << deps.map { |d| flags = d[0]._ldflags; flags.nil? ? "" : " " + flags }.join(" ")
  #         ldflags << deps.map { |d|
  #           if d[0].is_a? SystemLibrary
  #             ""
  #           else
  #             case d[1]
  #             when :any
  #               " -L#{d.out_dir} -l#{d.name}"
  #             when :static
  #               if !self.is_static?
  #                 Beaver::Log::err("Cannot statically link dynamic library #{d[0].name}")
  #               end
  #               tmp_dir = FileUtils.mkdir_p(File.join($beaver.temp_dir, "#{d[0].name}_static")).first
  #               FileUtils.cp(d[0].static_lib_path, tmp_dir)
  #               " -L#{tmp_dir} -l#{d[0].name}"
  #             when :dynamic
  #               Beaver::Log::err("Explicitly defining a dependency as dynamic is currently unimplemented")
  #             else
  #               Beaver::Log::err("Internal error: #{dep_type} is an invalid dependency type")
  #             end
  #           end
  #         }.join(" ")
  #       end
  #       return ldflags.strip
  #     end
  #     
  #     # recursively search for dependencies
  #     def _all_system_deps
  #       return nil if self.dependencies.nil?
  #       deps = []
  #       for dependency in self.dependencies
  #         dependency = self.project.get_target(dependency.name)
  #         if dependency.library_type == LibraryType::SYSTEM || dependency.library_type == LibraryType::PKG_CONFIG
  #           deps << dependency
  #         end
  #         sub_dependencies = dependency._all_system_deps
  #         if !sub_dependencies.nil?
  #             deps.push(*sub_dependencies)
  #         end
  #       end
  #       return deps.uniq
  #     end
  #     
  #     # TODO: args -> quoted
  #     
  #     private
  #     def self._get_compiler_for_file(file)
  #       if file.ext.downcase == ".c"
  #         $beaver.get_tool(:cc)
  #       elsif [".cc", ".cpp", ".cxx"].include? file.ext.downcase
  #         $beaver.get_tool(:cxx)
  #       else
  #         Beaver::Log::err("File extension #{file.ext} is not a valid C/C++ file extension")
  #       end
  #     end
  #     
  #     def self._parse_public_include(include)
  #       if include.is_a? String
  #         return "-I#{include}"
  #       elsif include.is_a? Hash
  #         return Target._parse_public_include(include[:public])
  #       elsif include.respond_to? :each
  #         return include.map { |folder| "-I#{folder} " }.join(" ")
  #       else
  #         Beaver::Log::err("Invalid include #{include.describe}")
  #       end
  #     end
  #     
  #     def parse_properties
  #       if self.sources.nil?
  #         Beaver::Log::err("#{self.name} has no source files defined")
  #       end
  #      
  #       if self.type.nil?
  #       elsif self.type.is_a? String
  #         self.type = self.type.to_sym
  #       elsif self.type.respond_to? :each
  #         self.type = self.type.map { |t| t.to_sym }
  #       end
  #       
  #       self.dependencies = C::Dependency.parse_dependency_list(self.dependencies, self.project.name)
  #     end
  #   end
  # end
  
  # module LibraryType
  #   USER = 0
  #   SYSTEM = 1
  #   PKG_CONFIG = 2
  # end
  # 
  # class Library < Internal::Target
  #   include Beaver::Internal::PostInitable
  #   include Beaver::Internal::TargetPostInit
  #   
  #   # Initializers #
  #   
  #   # Create a new system library
  #   # @param name [String] the name of the system library
  #   def self.system(name, system_name: nil, cflags: nil, ldflags: nil)
  #     _ldflags = nil #["-l#{system_name || name}"]
  #     if !ldflags.nil?
  #       if ldflags.respond_to? :each
  #         _ldflags = ldflags
  #       else
  #         _ldflags = [ldflags]
  #       end
  #     else
  #       _ldflags = []
  #     end
  #     _ldflags << "-l#{system_name || name}"
  #     
  #     return SystemLibrary.new(
  #       name: name,
  #       _type: LibraryType::SYSTEM,
  #       cflags: cflags,
  #       ldflags: _ldflags
  #     )  
  #   end
  #   
  #   # Create a new system library defined by pkg-config
  #   # @param name [String] the name of the pkg_config module
  #   # @param pkg_config_name [String] the name of the package config package, default is `name`
  #   # @param version [String] define a version for the package config module (e.g. ">= 1.2").
  #   def self.pkg_config(name, pkg_config_name: nil, version: ">= 0")
  #     # TODO: parse version -> check pkg-config --atleast-version, ...
  #     # TODO: error handling
  #     return SystemLibrary.new(
  #       name: name,
  #       _type: LibraryType::PKG_CONFIG,
  #       cflags:  `pkg-config #{pkg_config_name || name} --cflags`.gsub("\n", ""),
  #       ldflags: `pkg-config #{pkg_config_name || name} --libs`.gsub("\n", ""),
  #       version: version
  #     )
  #   end
  #   
  #   def executable?
  #     false
  #   end
  #   
  #   def buildable?
  #     true
  #   end
  #   
  #   def library_type
  #     if self._type.nil?
  #       return LibraryType::USER
  #     else
  #       return self._type
  #     end
  #   end
  #    
  #   def static_lib_path
  #     File.join(self.out_dir, "lib#{self.name}.a")
  #   end
  #   
  #   def dynamic_lib_path
  #     File.join(self.out_dir, "lib#{self.name}.so")
  #   end
  #   
  #   def pkg_config_path
  #     File.join(self.out_dir, "lib#{self.name}.pc")
  #   end
  #    
  #   def build_static_cmd_name
  #     "__build_#{self.project.name}/#{self.name}_static"
  #   end
  #   
  #   def build_dynamic_cmd_name
  #     "__build_#{self.name}_dynamic"
  #   end
  #   
  #   def build_if_not_built_yet
  #     if !@built_this_run
  #       self.build
  #     end
  #   end
  #   
  #   def build
  #     @built_this_run = true
  #     Workers.map(self.dependencies) do |dependency|
  #       self.project.get_target(dependency.name).build_if_not_built_yet
  #     end
  #     if self.type.nil? || ((self.type.is_a? Symbol) ? self.type == :static : (self.type.include? :static))
  #       Beaver::call self.build_static_cmd_name
  #     end
  #     if self.type.nil? || ((self.type.is_a? Symbol) ? self.type == :dynamic : (self.type.include? :dynamic))
  #       Beaver::call self.build_dynamic_cmd_name
  #     end
  #   end
  #   
  #   def create_pkg_config(path)
  #     contents = C::pkg_config_from_target(self)
  #     File.write(path, contents)
  #   end
  #
  #   def install
  #     # TODO!!
  #   end
  #   
  #   private
  #   def _custom_after_init
  #     self.parse_properties
  #
  #     # Create commands
  #     out_dir = self.out_dir
  #     obj_dir = self.obj_dir
  #     static_obj_dir = File.join(obj_dir, "static")
  #     dynamic_obj_dir = File.join(obj_dir, "dynamic")
  #     cc = if self.language == "C" || self.language.nil?
  #       $beaver.get_tool(:cc)
  #     elsif self.language == "C++"
  #       $beaver.get_tool(:cxx)
  #     elsif self.language == "Mixed"
  #       nil
  #     else
  #       Beaver::Log::err("Invalid language #{self.language} for C target")
  #     end
  #     # cc = $beaver.get_tool(:cc)
  #     # cxx = $beaver.get_tool(:cxx)
  #     ar = $beaver.get_tool(:ar)
  #     Beaver::def_dir(obj_dir)
  #     # cflags = self._cflags
  #     # include_flags = self._include_flags
  #     
  #     cmd_build_obj_static = "__build_#{self.project.name}/#{self.name}_obj_static"
  #     cmd_build_obj_dyn = "__build_#{self.project.name}/#{self.name}_obj_dyn"
  #     cmd_build_static_lib = "__build_#{self.project.name}/#{self.name}_static_lib"
  #     cmd_build_dyn_lib = "__build_#{self.project.name}/#{self.name}_dynamic_lib"
  #     cmd_build_pkg_config = "__build_#{self.project.name}/#{self.name}_pkg_config"
  #     
  #     static_obj_proc = proc { |f| File.join(static_obj_dir, f.path.gsub("/", "_") + ".o") }
  #     Beaver::cmd cmd_build_obj_static, Beaver::each(self.sources), out: static_obj_proc, parallel: true do |file, outfile|
  #       Beaver::sh "#{cc || C::Internal::_get_compiler_for_file(file)} " +
  #         "-c #{file} " +
  #         "#{self.private_cflags.join(" ")} " +
  #         "#{self.public_cflags.join(" ")} " +
  #         "#{self.private_includes.map { |i| "-I#{i}" }.join(" ")} " +
  #         "#{self.public_includes.map { |i| "-I#{i}" }.join(" ")} " +
  #         "-o #{outfile}"
  #     end
  #     
  #     dyn_obj_proc = proc { |f| File.join(dynamic_obj_dir, f.path.gsub("/","_") + ".o") }
  #     Beaver::cmd cmd_build_obj_dyn, Beaver::each(self.sources), out: dyn_obj_proc, parallel: true do |file, outfile|
  #       Beaver::sh "#{cc || C::Internal::_get_compiler_for_file(file)} " +
  #         "-c #{file} " +
  #         "-fPIC " +
  #         "#{self.private_cflags.join(" ")} " +
  #         "#{self.public_cflags.join(" ")} " +
  #         "#{self.private_includes.map { |i| "-I#{i}" }.join(" ")} " +
  #         "#{self.public_includes.map { |i| "-I#{i}" }.join(" ")} " +
  #         "-o #{outfile}"
  #     end
  #    
  #     outfiles = Beaver::eval_filelist(self.sources).map { |f| static_obj_proc.(SingleFile.new(f)) }
  #     Beaver::cmd cmd_build_static_lib, Beaver::all(outfiles), out: self.static_lib_path do |files, outfile|
  #       Beaver::sh "#{ar} -crs #{outfile} #{files}"
  #     end
  #     
  #     outfiles = Beaver::eval_filelist(self.sources).map { |f| dyn_obj_proc.(SingleFile.new(f)) }
  #     Beaver::cmd cmd_build_dyn_lib, Beaver::all(outfiles), out: self.dynamic_lib_path do |files, outfile|
  #       Beaver::sh "#{cc || $beaver.get_tool(:cxx)} #{files} -shared -o #{outfile}"
  #     end
  #
  #     # TODO: pkg_config with output onlly depenency
  #     # TODO voor output dependency: create cache file which tells it it should run next time
  #     Beaver::cmd cmd_build_pkg_config, out: self.pkg_config_path do |outfile|
  #       self.create_pkg_config(outfile)
  #     end
  #     
  #     Beaver::cmd self.build_static_cmd_name do
  #       Beaver::def_dir static_obj_dir
  #       Beaver::call cmd_build_obj_static 
  #       Beaver::call cmd_build_static_lib
  #       Beaver::call cmd_build_pkg_config
  #     end
  #     
  #     Beaver::cmd self.build_dynamic_cmd_name do
  #       Beaver::def_dir dynamic_obj_dir
  #       Beaver::call cmd_build_obj_dyn 
  #       Beaver::call cmd_build_dyn_lib 
  #       Beaver::call cmd_build_pkg_config
  #     end
  #   end
  # end
  
  # class SystemLibrary < Library
  #   def build
  #     self.dependencies.each do |dependency|
  #       self.project.get_target(dependency.name).build
  #     end
  #   end
  #   
  #   def buildable?
  #     false
  #   end
  #   
  #   private
  #   def _custom_after_init
  #     self.dependencies = C::Dependency.parse_dependency_list(self.dependencies, self.project.name)
  #   end
  # end
  # 
  # class Framework < Internal::Target
  #   include Beaver::Internal::PostInitable
  #   include Beaver::Internal::TargetPostInit
  #
  #   def executable?
  #     false
  #   end
  #
  #   def buildable?
  #     false
  #   end
  # end
  #
  # class Executable < Internal::Target
  #   include Beaver::Internal::PostInitable
  #   include Beaver::Internal::TargetPostInit
  #   
  #   def executable?
  #     true
  #   end
  #   
  #   def buildable?
  #     true
  #   end
  #   
  #   def executable_path
  #     File.join(self.out_dir, self.name)
  #   end
  #   
  #   def build_cmd_name
  #     "__build_#{self.project.name}/#{self.name}"
  #   end
  #   
  #   def build
  #     Workers.map(self.dependencies) do |dependency|
  #       target = self.project.get_target(dependency.name)
  #       Beaver::Log::err("Undefined target for deppendency #{dependency}") if target.nil?
  #       target.build_if_not_built_yet
  #     end
  #     Beaver::call self.build_cmd_name
  #   end
  #   
  #   def run
  #     system self.executable_path
  #   end
  #
  #   # Tools #
  #   def get_cc
  #     cc = if self.language == "C" || self.language.nil?
  #       $beaver.get_tool(:cc)
  #     elsif self.language == "C++"
  #       $beaver.get_tool(:cxx)
  #     elsif self.language == "Mixed"
  #       nil
  #     else
  #       Beaver::Log::err("Invalid language #{self.language}")
  #     end
  #     return cc
  #   end
  #   
  #   private 
  #   def _custom_after_init
  #     self.parse_properties
  #     
  #     if self.sources.nil?
  #       Beaver::Log::err("#{self.name} has no source files defined")
  #     end
  #     out_dir = self.out_dir
  #     obj_dir = self.obj_dir
  #     cc = if self.language.nil? || self.language == "C"
  #       $beaver.get_tool(:cc)
  #     elsif self.language == "C++"
  #       $beaver.get_tool(:cxx)
  #     elsif self.language == "Mixed"
  #       nil
  #     else
  #       Beaver::Log::err("Invalid language #{self.language}")
  #     end
  #     # cflags = self._cflags
  #     # ldflags = self._ldflags
  #     # include_flags = self._include_flags
  #
  #     cmd_build_obj = "__build_#{self.project.name}/#{self.name}_obj"
  #     cmd_link = "__build_#{self.project.name}/#{self.name}_link"
  #     
  #     Beaver::cmd cmd_build_obj, Beaver::each(self.sources), out: proc { |f| File.join(obj_dir, f.path.gsub("/", "_") + ".o") }, parallel: true do |file, outfile|
  #       Beaver::sh "#{cc || C::Internal::_get_compiler_for_file(file)} " +
  #         "-c #{file} " +
  #         "#{self.private_cflags.join(" ")} " +
  #         "#{self.public_cflags.join(" ")} " +
  #         "#{self.private_includes.map { |i| "-I#{i}" }.join(" ")} " +
  #         "#{self.public_includes.map { |i| "-I#{i}" }.join(" ")} " +
  #         "-o #{outfile}"
  #     end
  #     
  #     outfiles = Beaver::eval_filelist(self.sources).map { |f| File.join(obj_dir, f.gsub("/", "_") + ".o") }
  #     Beaver::cmd cmd_link, Beaver::all(outfiles), out: self.executable_path do |files, outfile|
  #       Beaver::sh "#{cc || $beaver.get_tool(:cxx)} #{files} #{self._ldflags} -o #{outfile}"
  #     end
  #     
  #     Beaver::cmd self.build_cmd_name do
  #       Beaver::def_dir obj_dir
  #       Beaver::call cmd_build_obj
  #       Beaver::call cmd_link
  #     end
  #   end
  # end
# end

