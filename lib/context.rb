require 'optparse'

# TODO: require_module/require_package -> separate beaver context so that commands of dependencies
# don't interfere. Every project and command then has a reference to the BeaverContext they belong to

# TODO: if main file changed, set force_run to true and delete all caches
module Beaver
  class BeaverContext
    attr_accessor :current_project
    attr_accessor :projects
    attr_accessor :commands
    # relative to base config file (or an absolute path)
    attr_accessor :cache_dir
    attr_accessor :cache_manager
    attr_accessor :force_run
    attr_accessor :executed_commands
    attr_accessor :option_parser
    # Parsed options
    # NOTE: this is only available at the end of the file scope,
    #       right before commands are executed!
    attr_reader :options
    attr_reader :postponed_callbacks
    
    def initialize
      @projects = Hash.new
      @commands = Hash.new
      @cache_dir = ENV["BEAVER_CACHE_DIR"] || ".beaver"
      Beaver::def_dir(@cache_dir)
      @force_run = false
      @executed_commands = []
      @option_parser = OptionParser.new
      @option_parser.banner = "Ussage: #{File.basename($0)} [command] [options]"
      @option_parser.on("-f", "--force", "Force rebuild the project")
      @option_parser.on("-v", "--[no-]verbose", "Print all shell commands")
      @option_parser.on("-h", "--help", "Prints this help message") do
        puts @option_parse
        exit 0
      end
      @options = {}
      self.default_option :verbose

      @postponed_callbacks = []
    end

    def default_option(option_name, value = true)
      if @options[option_name].nil?
        @options[option_name] = value
      end
    end

    def postpone(&cb)
      @postponed_callbacks << cb
    end

    def initialize_cache_manager
      @cache_manager = Internal::CacheManager.new
    end

    # Projects #
    def add_project(project)
      @projects[project.name] = project
    end

    def get_project(project_name)
      @projects[project_name]
    end

    # Commands #
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
      Dir.chdir(File.dirname($0)) do
        self.run("build")
        for command_name in @executed_commands.uniq
          command = self.get_command(command_name)
          if command.type == CommandType::NORMAL then next end
          @cache_manager.add_command_cache(command)
        end
        @cache_manager.add_config_cache
        @cache_manager.save
      end
    end
    
    # TODO: option parser (see notes in Project) (-f, command runner)
  end
 
  if $beaver.nil?
    $beaver = Beaver::BeaverContext.new
    $beaver.initialize_cache_manager
  end
  
  def call(command_name)
    $beaver.run(command_name)
  end
  
  at_exit {
    # $beaver.projects.each do |_, project|
      # project._options_callback.call($beaver.option_parser)
    # end
    if !$beaver.current_project.nil? && !$beaver.current_project._options_callback.nil?
      $beaver.current_project._options_callback.call($beaver.option_parser)
    end
    $beaver.options[:args] = $beaver.option_parser.parse!(ARGV, into: $beaver.options)

    $beaver.postponed_callbacks.each do |cb|
      case cb.arity
      when 0
        cb.call()
      when 1
        cb.call($beaver)
      when 2
        Beaver::Log::err("Too many arguments in postponed callback (got #{cb.arity}, expected 0..1)")
      end
    end

    if $!.nil? || ($!.is_a?(SystemExit) && $!.success?)
      $beaver.handle_exit
    end
  }
end

