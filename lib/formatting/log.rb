require 'rainbow/refinement'

module Beaver
  module Log
    using Rainbow

    def self.err(message, exit_status = 1)
      STDERR.puts "[ERR] #{message}".red
      $beaver.exit_error = true
      exit exit_status
    end

    def self.warn(message)
      STDERR.puts "[WARN] #{message}".yellow
    end

    # TODO: verbose settings
    def self.verbose(message)
      if $beaver.verbose
        STDERR.puts message
      end
    end

    def self.command_start(command_name)
      if $beaver.debug
        STDERR.puts "> #{command_name}".color(:dimgray)
      end
    end
    
    def self.shell_execute(shell_command)
      if $beaver.verbose
        STDERR.puts shell_command.color(:darkgray)
      end
    end
  end
end

