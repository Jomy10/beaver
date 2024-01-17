module Swift
  class SPMExecutable < SPMProduct
    def executable?
      true 
    end

    def buildable?
      true
    end

    def executable_path
      File.join(self.out_dir, self.name)
    end

    def artifact_path(artifact_type)
      case artifact_type
      when Beaver::ArtifactType::EXECUTABLE
        return self.executable_path
      else
        Beaver::Log::err("Invalid artifact #{artifact_type} for Swift::SPMExecutable")
    end

    def build
      @built_this_run = true
      call self.build_cmd
    end

    def run
      call self.run_cmd
    end

    private
    def _custom_after_init
      super()

      @artifacts = [Beaver::ArtifactType::EXECUTABLE]

      Beaver::cmd self.build_cmd do
        sh %(swift build #{self._flags})
      end

      Beaver::cmd self.run_cmd do
        sh %(swift run #{self._flags})
      end
    end

    def _flags
      "#{self.flags.join(" ")} --product #{self.name} -c #{self.proect.config_name}"
    end

    def build_cmd
      "__build_#{self.project}/#{self.name}"
    end

    def run_cmd
      "__run_#{self.project}/#{self.name}"
    end
end

