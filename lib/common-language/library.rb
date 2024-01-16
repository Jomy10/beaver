module Beaver
  module Internal
    module Library
      module Type
        def is_dynamic?
          return self.type.nil? || 
            ((self.type.respond_to? :map) && self.type.map{ |t| t.to_sym }.include?(:dynamic)) ||
            (self.type.respond_to?(:to_sym) && self.type.to_sym == :dynamic) ||
            false
        end
        
        def is_static?
          return self.type.nil? || 
            ((self.type.respond_to? :map) && self.type.map{ |t| t.to_sym }.include?(:static)) ||
            (self.type.respond_to?(:to_sym) && self.type.to_sym == :static) ||
            false
        end
      end
    end
  end
end

