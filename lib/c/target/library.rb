module C
  require 'pathname'
  
  class Library < C::Internal::Target
    # Initializers #
    
    # Create a new system library
    # @param name [String] the name of the system library
    def self.system(name, system_name: nil, cflags: nil, ldflags: nil)
      _ldflags = nil
      if !ldflags.nil?
        if ldflags.respond_to? :each
          _ldflags = ldflags
        else
          _ldflags = [ldflags]
        end
      else
        _ldflags = []
      end
      _ldflags << "-l#{system_name || name}"
      
      return SystemLibrary.new(
        name: name,
        _library_type: LibraryType::SYSTEM,
        cflags: cflags,
        ldflags: _ldflags
      )
    end
    
    # Create a new system library defined by pkg-config
    # @param name [String] the name of the pkg_config module
    # @param pkg_config_name [String] the name of the package config package, default is `name`
    # @param version [String] define a version for the package config module (e.g. ">= 1.2").
    def self.pkg_config(name, pkg_config_name: nil, version: ">= 0")
      # TODO: parse version -> check pkg-config --atleast-version, ...
      # TODO: error handling
      return SystemLibrary.new(
        name: name,
        _type: LibraryType::PKG_CONFIG,
        cflags:  `pkg-config #{pkg_config_name || name} --cflags`.gsub("\n", ""),
        ldflags: `pkg-config #{pkg_config_name || name} --libs`.gsub("\n", ""),
        version: version
      )
    end
    
    def self.framework(name, framework_name: nil, cflags: nil, ldflags: nil)
      _ldflags = if ldflags.nil?
        []
      else
        if ldflags.respond_to? :each
          ldflags
        else
          [ldflags]
        end
      end
      _ldflags << "-framework"
      _ldflags << (framework_name || name)
      
      return Framework.new(
        name: name,
        _library_type: LibraryType::FRAMEWORK,
        cflags: cflags,
        ldflags: _ldflags
      )
    end
    
    # General defines #
    def executable?
      false
    end

    def buildable?
      true
    end

    def library_type
      if self._library_type.nil?
        return LibraryType::USER
      else
        return self._library_type
      end
    end

    def is_dynamic?
      return self.type.nil? || 
        ((self.type.respond_to? :each) && self.type.map{ |t| t.to_sym }.include?(:dynamic)) ||
        ((self.type.respond_to? :to_sym && self.type.to_sym == :dynamic)) ||
        false
    end
    
    def is_static?
      return self.type.nil? || 
        ((self.type.respond_to? :each) && self.type.map{ |t| t.to_sym }.include?(:static)) ||
        ((self.type.respond_to? :to_sym && self.type.to_sym == :static)) ||
        false
    end
    
    # Paths #
    def static_lib_path
      Beaver::safe_join(self.abs_out_dir, "lib#{self.name}.a")
    end

    def dynamic_lib_path
      Beaver::safe_join(self.abs_out_dir, "lib#{self.name}.so")
    end

    def pkg_config_path
      Beaver::safe_join(self.abs_out_dir, "lib#{self.name}.pc")
    end

    # Command names #
    def build_static_cmd_name
      "__build_#{self.project.name}/#{self.name}_static"
    end
    
    def build_dynamic_cmd_name
      "__build_#{self.project.name}/#{self.name}_dynamic"
    end

    def build_pkg_config_cmd_name
      "__build_#{self.project.name}/#{self.name}_pkg_config"
    end

    # Build #
    def build_if_not_built_yet
      if !@built_this_run
        self.build
      end
    end
 
    def build
      @built_this_run = true
      
      self.build_dependencies
      
      @artifacts.each do |artifact|
        self.build_artifact(artifact)
      end
    end

    # TODO: pkg-config creation

    def install
      Beaver::Log::err("TODO")
    end

    # Artifacts #
    def build_artifact(artifact_type)
      case artifact_type
      when Beaver::ArtifactType::STATIC_LIB
        Beaver::call self.build_static_cmd_name
      when Beaver::ArtifactType::DYN_LIB
        Beaver::call self.build_dynamic_cmd_name
      when Beaver::ArtifactType::PKG_CONFIG_FILE
        Beaver::call self.build_pkg_config_cmd_name
      else
        Beaver::Log::err("Invalid artifact #{artifact_type} for C::Library")
      end
    end

    def artifact_path(artifact_type)
      case artifact_type
      when Beaver::ArtifactType::STATIC_LIB
        return self.static_lib_path
      when Beaver::ArtifactType::DYN_LIB
        return self.dynamic_lib_path
      when Beaver::ArtifactType::PKG_CONFIG_FILE
        return self.pkg_config_path
      else
        Beaver::Log::err("Invalid artifact #{artifact_type} for C::Library")
      end
    end

    private
    def _custom_after_init
      super()

      if !self.type.nil?
        if self.type.respond_to?(:map)
          self.type = self.type.map { |t| t.to_sym }
        else
          self.type = self.type.to_sym
        end
      end
     
      if self.buildable?
        self._create_build_commands
      end
    end

    def _create_build_commands
      @artifacts = []
      if self.type.nil? || ((self.type.is_a? Symbol) ? self.type == :static : (self.type.include? :static))
        @artifacts << Beaver::ArtifactType::STATIC_LIB
      end
      if self.type.nil? || ((self.type.is_a? Symbol) ? self.type == :dynamic : (self.type.include? :dynamic))
        @artifacts << Beaver::ArtifactType::DYN_LIB
      end
      @artifacts << Beaver::ArtifactType::PKG_CONFIG_FILE
      
      # Create commands
      out_dir = self.abs_out_dir
      obj_dir = self.obj_dir
      static_obj_dir = Beaver::safe_join(obj_dir, "static")
      dynamic_obj_dir = Beaver::safe_join(obj_dir, "dynamic")
      cc = self.get_cc
      ar = $beaver.get_tool(:ar)
      Beaver::def_dir(obj_dir)
      
      cmd_build_obj_static = "__build_#{self.project.name}/#{self.name}_obj_static"
      cmd_build_obj_dyn = "__build_#{self.project.name}/#{self.name}_obj_dyn"
      cmd_build_static_lib = "__build_#{self.project.name}/#{self.name}_static_lib"
      cmd_build_dyn_lib = "__build_#{self.project.name}/#{self.name}_dynamic_lib"
      
      filelist = Beaver::eval_filelist(self.sources, self.project.base_dir)
      
      static_obj_proc = proc { |f| File.join(static_obj_dir, Pathname.new(f.path).relative_path_from(self.project.base_dir).to_s.gsub("/", "_") + ".o") }
      Beaver::cmd cmd_build_obj_static, Beaver::each(filelist), out: static_obj_proc, parallel: true do |file, outfile|
        Beaver::sh "#{cc || C::Internal::Target::_get_compiler_for_file(file)} " +
          "-c #{file} " +
          "#{self.private_cflags.join(" ")} " +
          "#{self.public_cflags.join(" ")} " +
          "#{self.language == "Mixed" ? C::Internal::Target::_get_cflags_for_file(file).join(" ") : ""} " +
          "#{self.private_includes.map { |i| "-I#{i}" }.join(" ")} " +
          "#{self.public_includes.map { |i| "-I#{i}" }.join(" ")} " +
          "-o #{outfile}"
      end
      
      dyn_obj_proc = proc { |f| File.join(dynamic_obj_dir, Pathname.new(f.path).relative_path_from(self.project.base_dir).to_s.gsub("/", "_") + ".o") }
      Beaver::cmd cmd_build_obj_dyn, Beaver::each(filelist), out: dyn_obj_proc, parallel: true do |file, outfile|
        Beaver::sh "#{cc || C::Internal::Target::_get_compiler_for_file(file)} " +
          "-c #{file} " +
          "-fPIC " +
          "#{self.private_cflags.join(" ")} " +
          "#{self.public_cflags.join(" ")} " +
          "#{self.language == "Mixed" ? C::Internal::Target::_get_cflags_for_file(file).join(" ") : ""} " +
          "#{self.private_includes.map { |i| "-I#{i}" }.join(" ")} " +
          "#{self.public_includes.map { |i| "-I#{i}" }.join(" ")} " +
          "-o #{outfile}"
      end
      
      outfiles = filelist.map { |f| static_obj_proc.(SingleFile.new(f)) }
      Beaver::cmd cmd_build_static_lib, Beaver::all(outfiles), out: self.static_lib_path do |files, outfile|
        Beaver::sh "#{ar} -crs #{outfile} #{files}"
      end
      
      outfiles = filelist.map { |f| dyn_obj_proc.(SingleFile.new(f)) }
      Beaver::cmd cmd_build_dyn_lib, Beaver::all(outfiles), out: self.dynamic_lib_path do |files, outfile|
        Beaver::sh "#{cc || $beaver.get_tool(:cxx)} #{files} -shared -o #{outfile}"
      end
      
      # TODO voor output dependency: create cache file which tells it it should run next time
      Beaver::cmd self.build_pkg_config_cmd_name, out: self.pkg_config_path do |outfile|
        contents = C::pkg_config_from_target(self)
        File.write(outfile, contents)
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
      self.build_dependencies
    end
    
    # Makes it so that beaver build {TARGET} will fail
    def buildable?
      false
    end
  end
  
  class Framework < SystemLibrary
  end
  
  module LibraryType
    USER = 0
    SYSTEM = 1
    PKG_CONFIG = 2
    FRAMEWORK = 3
    
    def self.is_system?(library_type)
      return library_type != USER
    end
  end
end
