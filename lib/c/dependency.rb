module C
  # @param name [String] the dependency's name (e.g. "mylib", "myproject/mylib")
  # @param type [Symbol] :static, :dynamic, :any
  Dependency = Struct.new(:name, :type) do
    def initialize(name, type = :any); super end
    
    def self.parse_dependency_list(deps, project_name)
      return nil if deps.nil?
      return deps.map do |dep|
        if dep.is_a? String
          project = $beaver.get_project(project_name)
          Beaver::Log::err("Internal error: project is nil") if project.nil?
          target = project.get_target(dep)
          Beaver::Log::err("Unknown dependency #{dep}; target not found") if target.nil?
          if target.is_a? C::SystemLibrary
            next Dependency.new(dep)
          elsif target.is_static?
            next Dependency.new(dep, :static)
          elsif target.is_dynamic?
            next Dependency.new(dep, :dynamic)
          else
            Beaver::Log::err("Target #{dep} is neither static nor dynamic")
          end
        elsif dep.is_a?(C::Dependency)
          next dep
        else
          Beaver::Log::err("Dependency declaration #{dep} has wrong type #{dep.class}")
        end # type check
      end
    end
  end
end

def dynamic(dep_name)
  C::Dependency.new(dep_name, :dynamic)
end

def static(dep_name)
  C::Dependency.new(dep_name, :static)
end

