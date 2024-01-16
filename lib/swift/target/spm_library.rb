module Swift
  class SPMLibrary < SPMProduct
    def executable?
      false
    end

    def buildable?
      true
    end

    include Beaver::Internal::Library::Type

    def static_lib_path
      File.join(self.out_dir, "lib#{self.name}.a")
    end

    def dynamic_lib_path
      File.join(self.out_dir, "lib#{self.name}.so")
    end
    
    def artifact_path(artifact_type)
      case artifact_type
      when Beaver::ArtifactType::STATIC_LIB
        return self.static_lib_path
      when Beaver::ArtifactType::DYN_LIB
        return self.dynamic_lib_path
      else
        Beaver::Log::err("Invalid artifact #{artifact_type} for C::Library")
      end
    end

    def build_if_not_built_yet
      unless @built_this_run
        self.build
      end
    end

    def build
      @built_this_run = true
      call self.build_cmd
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

      @artifacts = []
      if self.is_static?
        @artifacts << Beaver::ArtifactType::STATIC_LIB
      end
      if self.is_dynamic?
        @artifacts << Beaver::ArtifactType::DYN_LIB
      end

      Beaver::cmd self.build_cmd do
        sh %(swift build #{self.flags.join(" ")} --product #{self.name} -c #{self.project.config_name})
      end
    end

    def build_cmd
      "__build_#{self.project}/#{self.name}"
    end
  end
end

