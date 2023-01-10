require 'file.rb'

class Command
  attr_accessor :name
  attr_accessor :fn

  def initialize(name, file_deps, fn)
    @name = name
    # When one of these files changes, the command should rerun
    # Type: FileDep, or nil
    @file_deps = file_deps
    @fn = fn
  end

  # Execute the command if needed (dependency files changed)
  def call
    if self.should_run?
      self.call_now()
    end
  end

  # Force call the command, even if none of the files changed
  def call_now
    $file = nil
    $files = nil

    if @file_deps.nil?
      @fn.call()
      return
    end
    
    if @file_deps.type == :each
      @file_deps.files.each do |file_obj|
        $file = file_obj
        @fn.call()
      end
    else
      $files = @file_deps.files
      @fn.call()
    end
  end

  # Returns wheter the command should run, meaning if any of the depency
  # files changed
  def should_run?
    if changed? "__BEAVER__CONFIG__", $PROGRAM_NAME
      # Ruby script itself changed
      # TODO: does not account for dependencies of the script (probably uncommon though)

      # Clear cache, because the config failed
      reset_cache

      unless @file_deps.nil?
        @file_deps.each_file do |file|
          $cache.files.add(@name, file)
        end
      end
      
      return true
    end
    
    if @file_deps.nil?
      return true
    end

    changed = false
    @file_deps.each_file do |file|
      if !changed && (changed? @name, file)
        changed = true
      end
      
      $cache.files.add(@name, file)
    end

    return changed
  end
end

def cmd(name, deps = nil, &fn)
  cmd = Command.new name, deps, fn
  $beaver.__appendCommand cmd
end
