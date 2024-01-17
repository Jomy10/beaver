module Beaver
  module Internal
    module PostInitable
      def self.included(base)
        class << base
          alias_method :_new, :new
          
          define_method :new do |*arg|
            _new(*arg).tap do |instance|
              instance.send(:after_init)
            end
          end
        end
      end
      
      def after_init
      end
    end
    
    module Target
      # Assign project and add target to project
      def after_init
        self.project = (self.project || $beaver.current_project)
        if self.project.nil?
          Beaver::Log::err "Cannot create target #{self.name} because you have not yet defined a project"
        end
        if !self.project.targets[self.name].nil?
          Beaver::Log::warn "Target with name #{self.name} specified multiple times"
        end
        Dir.chdir(self.project.base_dir) do
          self.project.targets[self.name] = self
          if self.class.private_method_defined? :_custom_after_init
            self._custom_after_init()
          end
        end
      end
      
      # [ArtifactType[]]
      def artifacts
        return @artifacts
      end
      
      # TODO: test artifacts
      def print_artifacts
        puts "Artifacts of #{self.name}:"
        @artifacts.each do |artifact|
          puts "  - #{ArtifactType::name(artifact)}: #{self.artifact_path(artifact)}"
        end
      end

      def build_if_not_built_yet
        unless @built_this_run
          self.build
        end
      end
    end
  end
  
  module ArtifactType
    STATIC_LIB = 0
    DYN_LIB = 1
    EXECUTABLE = 2
    MACOS_APP = 3
    PKG_CONFIG_FILE = 4
    
    def self.name(artifact_type)
      case artifact_type
      when STATIC_LIB
        return "Static library"
      when DYN_LIB
        return "Dynamic library"
      when EXECUTABLE
        return "Executable"
      else
        Beaver::Log::err("Invalid artifact type #{artifact_type}")
      end
    end
  end
end

