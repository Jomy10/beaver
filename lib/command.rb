module Beaver
  module CommandType
    NORMAL = 0
    EACH = 1
    ALL = 2
  end

  Command = Struct.new(
    :name,
    :project,
    :input,
    # [Proc | String] (Each, All)
    :output,
    :fn,
    :parallel, # TODO: run "each" calls in parallel
    :_force_should_run,
    keyword_init: true
  ) do
    def input_files
      return Beaver::eval_filelist(self.input.filelist)
    end
    
    def type
      if self.input.nil?
        return CommandType::NORMAL
      elsif self.input.type == DependencyType::EACH
        return CommandType::EACH
      elsif self.input.type == DependencyType::ALL
        return CommandType::ALL
      end
    end
    
    # returns wether this command should run (if type == ALL)
    def _all_should_run
      if self._force_should_run || $beaver.force_run
        return true
      end
       
      if !self.output.nil? && !File.exists?(self.output)
        # The output file is not present; create it
        return true
      end
      
      cache = $beaver.cache_manager.get_command_cache(self)
      if cache.nil? || cache["input"].nil?
        return true # no cache => run
      end
      
      for file in cache["input"]
        if File.exists?(file["path"]) && (File.mtime(file["path"]).to_i != file["modified"])
          # File was modified => rerun all
          return true
        end
      end
      
      return false
    end
    
    # Get a list of input files that did not change
    def _each_should_not_run_list
      if self._force_should_run || $beaver.force_run
        return []
      end
      
      cache = $beaver.cache_manager.get_command_cache(self)
      if cache.nil? || cache["input"].nil?
        return []
      end
      return cache["input"].filter { |file|
        if !File.exists?(file["path"])
          next false # input file doesn't exist, ignore it
        end
        
        if File.mtime(file["path"]).to_i != file["modified"]
          next false # modified times differ; re-run
        end
        
        next true # modified times equal; don't re-run
      }.map { |file| file["path"] }
    end
    
    def execute
      Beaver::Log::command_start(self.name)
      case self.type
      when CommandType::NORMAL
        if self.fn.arity != 0
          Beaver::Log::err("Invalid amount of arguments for command #{self.name} (got #{self.fn.arity}, expected: 1..2)")
        end
        self.fn.call()
      when CommandType::EACH
        input_list_ignore = self._each_should_not_run_list
        output_cb = self.output
        files = nil
        if self.output == nil
          files = self.input_files
            .filter { |file| !input_list_ignore.include?(file) }
        else
          files = self.input_files
            .map { |input_file|
              {
                input: input_file,
                output: self.output.(SingleFile.new(input_file))
              }
            }.filter { |files|
              # Don't re-run of the input file hasn't changed and the output file exists
              !(input_list_ignore.include?(files[:input]) && File.exist?(files[:output]))
            }
        end
        case self.fn.arity
        when 1
          if self.output == nil
            for file in files
              self.fn.call(file)
            end
          else
            for file_tuple in files
              self.fn.call(file_tuple[:input])
            end
          end
        when 2
          if self.output == nil
            Beaver::Log::err("No out: parameter given for command #{self.name}, but its block accepts two arguments (expected only 1)")
          else
            for file_tuple in files
              self.fn.call(file_tuple[:input], file_tuple[:output])
            end
          end
        when 3
          Beaver::Log::err("Invalid amount of arguments for command #{self.name} (got #{self.fn.arity}, expected: 1..2)")
        end
      when CommandType::ALL
        if self._all_should_run
          inputs = MultipleFiles.new(self.input_files)
          case self.fn.arity
          when 1
          :q
            self.fn.call(inputs)
          when 2
            self.fn.call(
              inputs,
              self.output
            )
          when 3
            Beaver::Log::err("Invalid amount of arguments for command #{self.name} (got #{self.fn.arity}, expected: 1..2)")
          end
        end
      end
      
      $beaver.executed_commands << self.name
    end
  end
  
  module DependencyType
    EACH = 0
    ALL = 1
  end
  
  Dependency = Struct.new(
    :filelist,
    :type
  )
  
  def each(*filelist)
    return Dependency.new(
      filelist.flatten,
      DependencyType::EACH
    )
  end
  
  def all(*filelist)
    return Dependency.new(
      filelist.flatten,
      DependencyType::ALL
    )
  end
  
  # @param name [String]
  # @pram project [Project] Optionally assign this command to a project
  # @param in [Dependency] A dependency containing a filelist of source files
  # @param out [Proc | String] A transform function from input to output (when dependency is each) or an output file (when dependency is all)
  def cmd(name, input = nil, out: nil, project: nil, parallel: false, &fn)
    $beaver.register(Command.new(
      name: name.to_s,
      project: project || $beaver.current_project,
      input: input,
      output: out,
      fn: fn,
      parallel: parallel,
      _force_should_run: false
    ))
  end
end

