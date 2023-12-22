require 'optparse'

module Beaver
  class Configuration
    # [String]
    attr_accessor :name
    # [{ LANG::ID => LANG::Options }]
    attr_accessor :lang_options
  end

  class Project
    # [String]
    attr_accessor :name
    # [String] build dir path
    attr_accessor :build_dir
    # [Configuration]
    attr_reader :configurations
    # attr :default_config
    # attr :current_config
    attr_reader :targets
    attr_reader :_options_callback

    def initialize(name, build_dir: "out", &options)
      @name = name
      @build_dir = build_dir
      @configurations = Hash.new
      @default_config = nil
      @current_config = nil # TODO: params
      @targets = Hash.new
      @_options_callback = options
   
      # TODO: in beave option parser which decides what poject to be run (in the Beaver.new method)
      # @options = {}
      # opt_parser = OptionParser.new do |opts|
      #   opts.banner = "Usage: #{$0} command [options]"
      #
      #   options.call(opts)
      #   opts.on("--cflags=FLAGS", Array, "Additional C flags")
      #   opts.on("--ldflags=FLAGS", Array, "Additional Linker flags")
      #   opts.on("-f", "--force", "Force rebuild the project")
      #   opts.on("-v", "--[no-]verbose", "Print all compiler commands")
      #   opts.on("-h", "--help", "Prints this help message") do
      #     # TODO: separate
      #     puts opts
      #     exit 1
      #   end
      # end
      # @options[:args] = opt_parser.parse!(ARGV, into: @options)
      
      $beaver.current_project = self
      $beaver.add_project(self)
    end

    # def default_option(option_name, value = true)
    #   if @options[option_name].nil?
    #     @options[option_name] = value
    #   end
    # end
   
    # TODO: different for non-selected projects
    def options
      return $beaver.options
    end

    def set_configs(*configs)
      for arg in configs
        @configurations[arg] = Hash.new
      end
    end

    def default_config=(newVal)
      if configurations[newVal] == nil
        Beaver::Log::err "configuration #{newVal} is not defined"
      end
      @default_config = newVal
    end

    def default_config
      return @default_config || configurations.first
    end

    # Get the current config's name or the default config
    def config_name
      return @current_config || self.default_config
    end

    # Get the current configuration for each language
    def config
      return @configurations[self.config_name]
    end

    def get_target(name)
      return self.targets[name]
      # TODO: retrn target from another project if separated by /
    end
  end

  # Internal
  $beaver.current_project = nil
end

