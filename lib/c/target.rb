module C
  module Internal
    Target = Struct.new(
      # [String]
      :name,
      # Valid values are: :static, :dynamic
      # [Symbol | Symbol[]]
      :type,
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
      # Either "C", "C++" or "Mixed"
      :language,
      :_type,
      keyword_init: true
    ) do 
      def out_dir
        File.join(self.project.build_dir, self.name)
      end
      
      def obj_dir
        File.join(self.out_dir, "obj")
      end
     
      # TODO: to lazy variable?
      def _cflags
        cflags = if self.cflags.nil?
          ""
        else
          (self.cflags.is_a? String) ? self.cflags : self.cflags.join(" ")
        end
        cflags << " " + self.project.cflags
        cflags.strip!
        return cflags
      end
      
      def _include_flags
        include_flags = if self.include.nil?
          ""
        else
          (Target._parse_private_include(self.include) || "")
            + (Target._parse_public_include(self.include) || "")
        end
        include_flags << " " + self.project.include_flags
        for dependency in self.dependencies
          include_flags << " " + self.project.get_target(dependency.name)._public_include_flags
        end
        include_flags.strip!
        # TODO: public include flags of dependencies
        return include_flags
      end
      
      def _public_include_flags
        include_flags = if self.include.nil?
          ""
        else
          Target._parse_public_include(self.include)
        end
        include_flags << " " + self.project.include_flags
        for dependency in self.dependencies
          include_flags << " " + self.project.get_target(dependency.name)._public_include_flags
        end
        include_flags.strip!
        return include_flags
      end

      def is_dynamic?
        return self.type.nil? || (self.type.is_a?(Symbol) && self.type == :dynamic) ||
          ((self.type.respond_to? :each) ? self.type.include?(:dynamic) : false)
      end

      def is_static?
        return self.type.nil? || (self.type.is_a?(Symbol) && self.type == :static) ||
          ((self.type.respond_to? :each) ? self.type.include?(:static) : false)
      end
      
      def _ldflags
        ldflags = if self.ldflags.nil?
          ""
        else
          (self.ldflags.is_a? String) ? self.ldflags : self.ldflags.join(" ")
        end
        if !self.dependencies.nil?
          deps = self.dependencies.map { |d| [self.project.get_target(d.name), d.type] }
          ldflags << deps.map { |d| flags = d[0]._ldflags; flags.nil? ? "" : " " + flags }.join(" ")
          ldflags << deps.map { |d|
            if d[0].is_a? SystemLibrary
              ""
            else
              case d[1]
              when :any
                " -L#{d.out_dir} -l#{d.name}"
              when :static
                if !self.is_static?
                  Beaver::Log::err("Cannot statically link dynamic library #{d[0].name}")
                end
                tmp_dir = FileUtils.mkdir_p(File.join($beaver.temp_dir, "#{d[0].name}_static")).first
                FileUtils.cp(d[0].static_lib_path, tmp_dir)
                " -L#{tmp_dir} -l#{d[0].name}"
              when :dynamic
                Beaver::Log::err("Explicitly defining a dependency as dynamic is currently unimplemented")
              else
                Beaver::Log::err("Internal error: #{dep_type} is an invalid dependency type")
              end
            end
          }.join(" ")
        end
        return ldflags.strip
      end
      
      # recursively search for dependencies
      def _all_system_deps
        return nil if self.dependencies.nil?
        deps = []
        for dependency in self.dependencies
          dependency = self.project.get_target(dependency.name)
          if dependency.library_type == LibraryType::SYSTEM
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
      
      private
      # Include can be of type:
      # - String
      # - String[]
      # - { :internal => String | String[], :public => String | String[] }
      def self._parse_private_include(include)
        if include.is_a? Hash
          Target._parse_public_include(include[:private])
        end
        # if include.is_a? String
        #   return "-I#{include}"
        # elsif include.is_a? Hash
        #   return include.map { |k, v| Target._parse_include(v) }.join(" ")
        # elsif include.respond_to? :each
        #   return include.map { |folder| "-I#{folder} " }.join(" ")
        # else
        #   Beaver::Log::err("Invalid include #{include.describe}")
        # end
      end
      
      def self._get_compiler_for_file(file)
        if file.ext.downcase == ".c"
          $beaver.get_tool(:cc)
        elsif [".cc", ".cpp", ".cxx"].include? file.ext.downcase
          $beaver.get_tool(:cxx)
        else
          Beaver::Log::err("File extension #{file.ext} not a valid C/C++ file")
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

      def parse_properties
        if self.sources.nil?
          Beaver::Log::err("#{self.name} has no source files defined")
        end
       
        if self.type.nil?
        elsif self.type.is_a? String
          self.type = self.type.to_sym
        elsif self.type.respond_to? :each
          self.type = self.type.map { |t| t.to_sym }
        end
        
        self.dependencies = C::Dependency.parse_dependency_list(self.dependencies, self.project.name)
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
    
    def executable?
      false
    end
    
    def buildable?
      true
    end
    
    def library_type
      if self._type.nil?
        return LibraryType::USER
      else
        return self._type
      end
    end
     
    def static_lib_path
      File.join(self.out_dir, "lib#{self.name}.a")
    end
    
    def dynamic_lib_path
      File.join(self.out_dir, "lib#{self.name}.so")
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
      return SystemLibrary.new(
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
      return SystemLibrary.new(
        name: name,
        _type: LibraryType::SYSTEM,
        cflags:  `pkg-config #{pkg_config_name || name} --cflags`.gsub("\n", ""),
        ldflags: `pkg-config #{pkg_config_name || name} --libs`.gsub("\n", "")
      )
    end
    
    def build_static_cmd_name
      "__build_#{self.project.name}/#{self.name}_static"
    end
    
    def build_dynamic_cmd_name
      "__build_#{self.name}_dynamic"
    end

    def build_if_not_built_yet
      if !@built_this_run
        self.build
      end
    end
    
    def build
      @built_this_run = true
      Workers.map(self.dependencies) do |dependency|
        self.project.get_target(dependency.name).build_if_not_built_yet
      end
      if self.type.nil? || ((self.type.is_a? Symbol) ? self.type == :static : (self.type.include? :static))
        Beaver::call self.build_static_cmd_name
      end
      if self.type.nil? || ((self.type.is_a? Symbol) ? self.type == :dynamic : (self.type.include? :dynamic))
        Beaver::call self.build_dynamic_cmd_name
      end
    end
    
    def create_pkg_config
      # TODO!!!
    end

    def install
      # TODO!!
    end
    
    private
    def _custom_after_init
      self.parse_properties

      # Create commands
      out_dir = self.out_dir
      obj_dir = self.obj_dir
      static_obj_dir = File.join(obj_dir, "static")
      dynamic_obj_dir = File.join(obj_dir, "dynamic")
      cc = if self.language == "C" || self.language.nil?
        $beaver.get_tool(:cc)
      elsif self.language == "C++"
        $beaver.get_tool(:cxx)
      elsif self.language == "Mixed"
        nil
      else
        Beaver::Log::err("Invalid language #{self.language} for C target")
      end
      # cc = $beaver.get_tool(:cc)
      # cxx = $beaver.get_tool(:cxx)
      ar = $beaver.get_tool(:ar)
      Beaver::def_dir(obj_dir)
      # cflags = self._cflags
      # include_flags = self._include_flags
      
      cmd_build_obj_static = "__build_#{self.project.name}/#{self.name}_obj_static"
      cmd_build_obj_dyn = "__build_#{self.project.name}/#{self.name}_obj_dyn"
      cmd_build_static_lib = "__build_#{self.project.name}/#{self.name}_static_lib"
      cmd_build_dyn_lib = "__build_#{self.project.name}/#{self.name}_dynamic_lib"
      
      static_obj_proc = proc { |f| File.join(static_obj_dir, f.path.gsub("/", "_") + ".o") }
      Beaver::cmd cmd_build_obj_static, Beaver::each(self.sources), out: static_obj_proc, parallel: true do |file, outfile|
        Beaver::sh "#{cc || C::Internal::_get_compiler_for_file(file)} " +
          "-c #{file} " +
          "#{self._cflags} " +
          "#{self._include_flags} " +
          "-o #{outfile}"
      end
      
      dyn_obj_proc = proc { |f| File.join(dynamic_obj_dir, f.path.gsub("/","_") + ".o") }
      Beaver::cmd cmd_build_obj_dyn, Beaver::each(self.sources), out: dyn_obj_proc, parallel: true do |file, outfile|
        Beaver::sh "#{cc || C::Internal::_get_compiler_for_file(file)} " +
          "-c #{file} " +
          "-fPIC " +
          "#{self._cflags} " +
          "#{self._include_flags} " +
          "-o #{outfile}"
      end
     
      outfiles = Beaver::eval_filelist(self.sources).map { |f| static_obj_proc.(SingleFile.new(f)) }
      Beaver::cmd cmd_build_static_lib, Beaver::all(outfiles), out: self.static_lib_path do |files, outfile|
        Beaver::sh "#{ar} -crs #{outfile} #{files}"
      end
      
      outfiles = Beaver::eval_filelist(self.sources).map { |f| dyn_obj_proc.(SingleFile.new(f)) }
      Beaver::cmd cmd_build_dyn_lib, Beaver::all(outfiles), out: self.dynamic_lib_path do |files, outfile|
        Beaver::sh "#{cc || $beaver.get_tool(:cxx)} #{files} -shared -o #{outfile}"
      end
      
      Beaver::cmd self.build_static_cmd_name do
        Beaver::def_dir static_obj_dir
        Beaver::call cmd_build_obj_static 
        Beaver::call cmd_build_static_lib 
      end
      
      Beaver::cmd self.build_dynamic_cmd_name do
        Beaver::def_dir dynamic_obj_dir
        Beaver::call cmd_build_obj_dyn 
        Beaver::call cmd_build_dyn_lib 
      end
    end
  end

  class SystemLibrary < Library
    def build
      self.dependencies.each do |dependency|
        self.project.get_target(dependency.name).build
      end
    end

    def buildable?
      false
    end
    
    private
    def _custom_after_init
      self.dependencies = C::Dependency.parse_dependency_list(self.dependencies, self.project.name)
    end
  end
  
  class Executable < Internal::Target
    include Beaver::Internal::PostInitable
    include Beaver::Internal::TargetPostInit
    
    def executable?
      true
    end

    def buildable?
      true
    end
    
    def executable_path
      File.join(self.out_dir, self.name)
    end
    
    def build_cmd_name
      "__build_#{self.project.name}/#{self.name}"
    end
    
    def build
      Workers.map(self.dependencies) do |dependency|
        target = self.project.get_target(dependency.name)
        Beaver::Log::err("Undefined target for deppendency #{dependency}") if target.nil?
        target.build_if_not_built_yet
      end
      Beaver::call self.build_cmd_name
    end
    
    def run
      system self.executable_path
    end
    
    private 
    def _custom_after_init
      self.parse_properties

      if self.sources.nil?
        Beaver::Log::err("#{self.name} has no source files defined")
      end
      out_dir = self.out_dir
      obj_dir = self.obj_dir
      # cc = $beaver.get_tool(:cc)
      cc = if self.language == "C" || self.language.nil?
        $beaver.get_tool(:cc)
      elsif self.language == "C++"
        $beaver.get_tool(:cxx)
      elsif self.language == "Mixed"
        nil
      else
        Beaver::Log::err("Invalid language #{self.language}")
      end
      # cflags = self._cflags
      # ldflags = self._ldflags
      # include_flags = self._include_flags

      cmd_build_obj = "__build_#{self.project.name}/#{self.name}_obj"
      cmd_link = "__build_#{self.project.name}/#{self.name}_link"
      
      Beaver::cmd cmd_build_obj, Beaver::each(self.sources), out: proc { |f| File.join(obj_dir, f.path.gsub("/", "_") + ".o") }, parallel: true do |file, outfile|
        Beaver::sh "#{cc || C::Internal::_get_compiler_for_file(file)} " +
          "-c #{file} " +
          "#{self._cflags} " +
          "#{self._include_flags} " +
          "-o #{outfile}"
      end
      
      outfiles = Beaver::eval_filelist(self.sources).map { |f| File.join(obj_dir, f.gsub("/", "_") + ".o") }
      Beaver::cmd cmd_link, Beaver::all(outfiles), out: self.executable_path do |files, outfile|
        Beaver::sh "#{cc || $beaver.get_tool(:cxx)} #{files} #{self._ldflags} -o #{outfile}"
      end
      
      Beaver::cmd self.build_cmd_name do
        Beaver::def_dir obj_dir
        Beaver::call cmd_build_obj
        Beaver::call cmd_link
      end
    end
  end
end

