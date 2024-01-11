module C
  class Executable < C::Internal::Target
    # General defines #
    def executable?
      true
    end
    
    def buildable?
      true
    end
    
    # Paths #
    def executable_path
      File.join(self.out_dir, self.name)
    end
    
    # Commands #
    def build_cmd_name
      "__build_#{self.project.name}/#{self.name}"
    end
 
    # Build #
    def build_if_not_built_yet
      unless @built_this_run
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

    def run
      system self.executable_path
    end
    
    def install
      Beaver::Log::err("TODO")
    end
    
    # Artifacts #
    def build_artifact(artifact_type)
      case artifact_type
      when Beaver::ArtifactType::EXECUTABLE
        Beaver::call self.build_cmd_name
      when Beaver::ArtifactType::MACOS_APP
        Beaver::Log::err("MacOS Apps are currently unimplemented")
      else
        Beaver::Log::err("Invalid artifact #{artifact_type} for C::Executable")
      end
    end
    
    def artifact_path(artifact_type)
      case artifact_type
      when Beaver::ArtifactType::EXECUTABLE
        return self.executable_path
      when Beaver::ArtifactType::MACOS_APP
        Beaver::Log::err("MacOS Apps are currently unimplemented")
      else
        Beaver::Log::err("Invalid artifact #{artifact_type} for C::Executable")
      end
    end
    
    private
    def _custom_after_init
      super()
      
      # TODO: build .app for macOS
      @artifacts = [Beaver::ArtifactType::EXECUTABLE]
      
      out_dir = self.out_dir
      obj_dir = self.obj_dir
      cc = self.get_cc
      
      cmd_build_obj = "__build_#{self.project.name}/#{self.name}_obj"
      cmd_link = "__build_#{self.project.name}/#{self.name}_link"
      
      Beaver::cmd cmd_build_obj, Beaver::each(self.sources), out: proc { |f| File.join(obj_dir, f.path.gsub("/", "_") + ".o") }, parallel: true do |file, outfile|
        Beaver::sh "#{cc || C::Internal::Target::_get_compiler_for_file(file)} " +
          "-c #{file} " +
          "#{self.private_cflags.join(" ")} " +
          "#{self.public_cflags.join(" ")} " +
          "#{self.language == "Mixed" ? C::Internal::Target::_get_cflags_for_file(file).join(" ") : ""} " +
          "#{self.private_includes.map { |i| "-I#{i}" }.join(" ")} " +
          "#{self.public_includes.map { |i| "-I#{i}" }.join(" ")} " +
          "-o #{outfile}"
      end
      
      outfiles = Beaver::eval_filelist(self.sources).map { |f| File.join(obj_dir, f.gsub("/", "_") + ".o") }
      Beaver::cmd cmd_link, Beaver::all(outfiles), out: self.executable_path do |files, outfile|
        Beaver::sh "#{cc || $beaver.get_tool(:cxx)} #{files} " +
          "#{self.public_ldflags.join(" ")} " +
          "#{self.language == "Mixed" ? C::Internal::Target::_get_ldflags_for_file(file).join(" "): ""} " +
          "-o #{outfile}"
      end
      
      Beaver::cmd self.build_cmd_name do
        Beaver::def_dir obj_dir
        Beaver::call cmd_build_obj
        Beaver::call cmd_link
      end
    end
  end
end

