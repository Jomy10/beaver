# Shell commands

# Execute shell command
def sh(strcmd)
  unless strcmd.is_a?(SilentCommand) || strcmd.is_a?(SilentAll) then
    if $beaver.term_256_color
      puts "\u001b[38;5;246m#{strcmd}\u001b[0m"
    else
      puts "\u001b[30;1m#{strcmd}\u001b[0m"
    end
  end

  if strcmd.is_a?(SilentAll) || strcmd.is_a?(SilentOutput)
    `#{strcmd}`
  else
    puts `#{strcmd}`
  end

  if $beaver.has(:e)
    if $?.to_i != 0
      if $?.exitstatus.nil?
        puts $?
      end
      exit($?.exitstatus || -1)
    end
  elsif $?.to_i != 0 && $?.exitstatus.nil?
    puts $?
  end
end

SilentCommand = Struct.new(:strcmd) do
  def to_s
    strcmd
  end
end
SilentAll = Struct.new(:strcmd) do
  def to_s
    strcmd
  end
end
SilentOutput = Struct.new(:strcmd) do
  def to_s
    strcmd
  end
end

# Do not print the command
def silent(strcmd)
  return SilentCommand.new(strcmd)
end

# Do not print the command, or the output of the command
def full_silent(strcmd)
  return SilentAll.new(strcmd)
end

# Do not print out the output of the command
def output_silent(strcmd)
  return SilentOutput.new(strcmd)
end
