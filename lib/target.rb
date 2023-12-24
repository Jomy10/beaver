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
    
    module TargetPostInit
      # Assign project and add target to project
      def after_init
        self.project = (self.project || $beaver.current_project)
        if self.project.nil?
          Beaver::Log::err "You have not yet defined a project"
        end
        if self.project.targets[self.name]
          Beaver::Log::warn "Target with name #{self.name} specified multiple times"
        end
        self.project.targets[self.name] = self
        if self.class.private_method_defined? :_custom_after_init
          self._custom_after_init()
        end
      end
    end
  end
end

