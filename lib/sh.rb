require 'rainbow'

module Beaver
  module Internal
    def self.execute_shell(command, output = true)
      if output
        Beaver::Log::shell_execute(command)
      end
      if !system(command)
        Beaver::Log::err("Error while running #{command}", $?.exitstatus || -1)
      end
    end
  end
  
  def sh(strcmd)
    Internal::execute_shell(strcmd)
  end

  # Doesn't print the command
  def _sh(strcmd)
    Internal::execute_shell(strcmd, false)
  end
end

