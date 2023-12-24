require 'optparse'
require 'rainbow/refinement'

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
    attr_reader :tools
    
    def initialize 
      @projects = Hash.new
      @commands = Hash.new
      @cache_dir = ENV["BEAVER_CACHE_DIR"] || ".beaver"
      Beaver::def_dir(@cache_dir)
      @force_run = false
      @executed_commands = []
      @option_parser = OptionParser.new
      @option_parser.banner = <<-USAGE
Usage: #{File.basename($0)} [command] [options]

#{Rainbow("Commands:").bright}
build [target]    Build the specified target
run [target]      Build and run the specified executable target

#{Rainbow("Options:").bright}
      USAGE
      @option_parser.on("-f", "--force", "Force run commands")
      @option_parser.on("-v", "--[no-]verbose", "Print all shell commands")
      @option_parser.on("-h", "--help", "Prints this help message") do
        puts @option_parser
        exit 0
      end
      @options = {}
      self.default_option :verbose
      
      @postponed_callbacks = []
      @tools = {
        cc: ENV["CC"] || "clang",
        cxx: ENV["CXX"] || "clang++",
        ar: ENV["AR"] || "ar",
      }
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
        Beaver::Log::warn("Redefined command #{command.name}")
      end

      @commands[command.name] = command
    end

    def get_command(command_name)
      return @commands[command_name.to_s]
    end

    def default_command
      return @commands.first
    end
    
    def run(command_name)
      command = @commands[command_name.to_s]
      if command.nil?
        Beaver::Log::err("Invalid command #{command_name}, valid commands are: #{@commands.map { |k,v| "`#{k}`" }.join(" ") }")
      end
      # TODO: context?
      command.execute()
    end
    
    def call_command_at_exit(args)
      Dir.chdir(File.dirname($0)) do
        args = @options[:args]
        self.run(args.count == 0 ? self.default_command : args[0])
      end
    end

    def save_cache
      Dir.chdir(File.dirname($0)) do
        for command_name in @executed_commands.uniq
          command = self.get_command(command_name)
          if command.type == CommandType::NORMAL then next end
          @cache_manager.add_command_cache(command)
        end
        @cache_manager.add_config_cache
        @cache_manager.save
      end
    end
    
    def arg_run(target)
      target.build
      target.run
    end
    
    def arg_build(target)
      target.build
    end
    
    # Return true if the arguments were handled by this function
    def handle_arguments
      args = @options[:args]
      if args.count == 0 then return false end
      case args[0]
      when "run"
        if args.count == 1
          executables = self.current_project.targets
            .filter { |_,t| t.executable? }
          if executable.count == 1
            self.arg_run(executables.map { |_,v| v }.first)
          else
            Beaver::Log::err("Multiple executable targets found, please specify one #{executables.map { |t,_| "`#{t}`" }.join(" ")}")
          end
        else
          self.arg_run(self.current_project.get_target(args[1]))
        end
      # TODO: allow build all
      when "build"
        if args.count == 1
          targets = self.current_project.targets
          if targets.count == 1
            self.arg_build(targets.map { |_,v| v }.first)
          else
            Beaver::Log::err("Multiple targets found, please specify one #{targets.map { |t,_| "`#{t}`" }.join(" ")}")
          end
        else
          self.arg_build(self.current_project.get_target(args[1]))
        end
      else
        Beaver::Log::err("Unknown command #{args[0]}\n#{Rainbow(@option_parser).white}")
      end
    end
  end
  
  if $beaver.nil?
    $beaver = Beaver::BeaverContext.new
    $beaver.initialize_cache_manager
  end
  
  def call(command_name)
    $beaver.run(command_name)
  end
  
  at_exit {
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
    
    if !$beaver.handle_arguments
      if $!.nil? || ($!.is_a?(SystemExit) && $!.success?)
        $beaver.call_command_at_exit
      end
    end
    
    $beaver.save_cache
  }
end

