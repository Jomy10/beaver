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
      def after_init
        self.project = (self.project || $beaver.current_project)
        if self.project.nil?
          Beaver::Log::err "You have not yet defined a project"
        end
        if self.project.targets[self.name]
          Beaver::Log::warn "Target with name #{self.name} specified multiple times"
        end
        self.project.targets[self.name] = self
      end
    end
  end
end

