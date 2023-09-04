require 'fileutils'

class Beaver
  # The location where beaver stores its info about files, etc
  attr_accessor :cache_loc
  # whether the current terminal supports 256 color support
  attr_accessor :term_256_color
  attr_accessor :opts

  # Initialize functon should not be used by build scripts
  def initialize
    # Contains all commands
    # { CommandName: Symbol => command: Command }
    @commands = Hash.new
    # Name of the main command
    @mainCommand = nil
    @cache_loc = "./.beaver"
    unless Dir.exist? @cache_loc
      Dir.mkdir @cache_loc
    end
    @term_256_color = `echo $TERM`.include? "256color"
    @opts = []
  end

  def file_cache_file
    file_loc = File.join(@cache_loc, "files.info")
    unless File.exist? file_loc
      FileUtils.touch file_loc
    end
    return file_loc
  end

  # Set an option
  # :e = exit on non-zero exit code of `sh` execution
  def set(opt)
    @opts << opt.to_sym
  end

  # Check if an option is present
  def has(opt)
    @opts.include? opt
  end

  # Remove an option
  def rm(opt)
    @opts.delete opt
  end

  # Append a command to the global beaver object
  # - cmd: Command
  def __appendCommand(cmd)
    if @commands.size == 0
      @mainCommand = cmd.name
    end

    @commands[cmd.name] = cmd
  end

  def command_exists?(cmd)
    return @commands[cmd.to_sym] != nil
  end

  # Call a command
  def call(cmd)
    _cmd = @commands[cmd.to_sym]
    if _cmd.nil?
      STDERR.puts "No command called #{cmd} found"
      exit 1
    end

    _cmd.call
  end

  # Run this command when it is called, no matter if its dependencies did not change
  def must_run cmd
    _cmd = @commands[cmd.to_sym]
    if _cmd.nil?
      STDERR.puts "\001b[31mNON-FATAL ERROR\001b[0m: Command #{cmd} does not exist, so `must_run` has not effect"
      exit 1
    end
    _cmd.overwrite_should_run = true

    _cmd.call
  end

  def set_main(cmd)
    @mainCommand = cmd.to_sym
  end

  # Put this at the end of a file
  def end
    $cache = CacheManager.new # load cache file
    
    command = ARGV[0] || @mainCommand
    if command == "--" # passing arguments to be processed by the builld file -> pass "--" as the command to specify the default
      command = @mainCommand
    end
    self.call command

    $cache.save # save cache file
  end

  # Returns all available commands as an array
  def list_commands
    return @commands.map { |k, v| k }
  end

  # Clean cache
  def clean
    FileUtils.rm_r @cache_loc
    reset_cache
  end
end

$beaver = Beaver.new

# Export functions
require 'command'
require 'file'
require 'file_dep'
require 'sh'

# Call a command
def call(cmd)
  $beaver.call cmd
end

def must_run(cmd)
  $beaver.must_run cmd
end
