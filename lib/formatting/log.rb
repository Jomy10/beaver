require 'rainbow/refinement'

module Beaver
  module Log
    using Rainbow

    def self.err(message, exit_status = 1)
      STDERR.puts "[ERR] #{message}".red
      exit exit_status
    end

    def self.warn(message)
      STDERR.puts "[WARN] #{message}".yellow
    end

    # TODO: verbose settings
    def self.verbose(message)
      STDERR.puts message
    end

    def self.command_start(command_name)
      STDERR.puts "> #{command_name}".color(:dimgray)
    end
    
    def self.shell_execute(shell_command)
      STDERR.puts shell_command.color(:darkgray)
    end
  end
end

