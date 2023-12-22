require 'rainbow/refinement'

module Beaver
  module Log
    using Rainbow

    def self.err(message)
      STDERR.puts "[ERR] #{message}".red
      exit 1
    end

    def self.warn(message)
      STDERR.puts "[WARN] #{message}".yellow
    end

    # TODO: verbose settings
    def self.verbose(message)
      STDERR.puts message
    end

    def self.command_start(command_name)
      STDERR.puts "> #{command_name}".black.bright
    end
    
    def self.shell_execute(shell_command)
      STDERR.puts shel_command.color(:lightgray) # or :dimgray
    end
  end
end

