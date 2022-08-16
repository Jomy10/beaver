require 'fileutils'

# Export functions
require 'file_change'
require 'file_exists'
require 'command'
require 'alias'

class Beaver
  # The location where Beaver caches
  attr_accessor :cache_loc
  
  # Initializer should not be used outside of this module
  def initialize
    # Contains all commands
    # [commandName: String => command: Function]
    @commands = Hash.new
    # Contains the main command name
    @mainCommand = nil
    @cache_loc = "./.beaver"
  end
  
  # Appends a command to the global beaver
  def __appendCommand(name, func)
    if @commands.size == 0
      @mainCommand = name.to_sym
    end
    
    @commands[name.to_sym] = func
  end
  
  def __appendCommandCB(name, &func)
    self.__appendCommand(name, func)
  end
  
  # Call a command
  def call(cmd)
    _cmd = @commands[cmd.to_sym]
    if _cmd.nil?
      puts "No command called #{cmd} found"
      exit 1
    end
    
    _cmd.call
  end
  
  # Put this at the end of a file
  def end
    command = ARGV[0] || @mainCommand
    self.call command
  end
  
  # Clean beaver
  def clean
    FileUtils.rm_r @cache_loc
  end
end

# Global beaver object
$beaver = Beaver.new
