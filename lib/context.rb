# TODO: require_module/require_package -> separate beaver context so that commands of dependencies
# don't interfere. Every project and command then has a reference to the BeaverContext they belong to

# TODO: if main file changed, set force_run to true and delete all caches
module Beaver
  class BeaverContext
    attr_accessor :current_project
    attr_accessor :projects
    attr_accessor :commands
    attr_accessor :cache_dir
    attr_accessor :cache_manager
    attr_accessor :force_run
    attr_accessor :executed_commands
    
    def initialize
      @projects = Hash.new
      @commands = Hash.new
      @cache_dir = ENV["BEAVER_CACHE_DIR"] || ".beaver"
      Beaver::def_dir(@cache_dir)
      @force_run = false
      @executed_commands = []
    end

    def initialize_cache_manager
      @cache_manager = Internal::CacheManager.new
    end

    def register(command)
      if !@commands[command.name].nil?
        Beaver::Logger::warn("Redefined command #{command}")
      end

      @commands[command.name] = command
    end

    def get_command(command_name)
      return @commands[command_name.to_s]
    end
    
    def run(command_name)
      command = @commands[command_name.to_s]
      if command.nil?
        Beaver::Log::err("Invalid command #{command_name}, valid commands are: #{@commands.map { |k,v| "`#{k}`" }.join(" ") }")
      end
      # TODO: context?
      command.execute()
    end
    
    def handle_exit
      self.run("build")
      for command_name in @executed_commands.uniq
        command = self.get_command(command_name)
        if command.type == CommandType::NORMAL then next end
        @cache_manager.add_command_cache(command)
      end
      @cache_manager.add_config_cache
      @cache_manager.save
    end
    
    # TODO: option parser (see notes in Project) (-f, command runner)
  end
  
  $beaver = Beaver::BeaverContext.new
  $beaver.initialize_cache_manager
  
  def call(command_name)
    $beaver.run(command_name)
  end
  
  at_exit {
    $beaver.handle_exit
  }
end

