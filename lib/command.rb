require 'pathname'
require 'file_matches'

# register a new beaver command
#
# - Possible combinations
# Register a normal command
#   command :name do end
# Register a command that executes if a source file changed, or the target file does not exist (one target file per source file)
#   command :name, src: "", target_dir: "", target_ext: "", do end
# Register a command that executes if a source file changed, or the single target file does not exist (multiple sources into one target file)
# The callback will receive a files variables, which is a string containing all paths, separated by spaces
#   command :name, src: "", target: "" do end
def command(name, src:nil, target_dir:nil, target_ext:nil, target:nil, &func)
  if !src.nil? && !target_dir.nil? && !target_ext.nil?
    _command_oto name, src:src, target_dir:target_dir, target_ext:target_ext do |src, trg|
      func.call src, trg
    end
  elsif !src.nil? && !target.nil?
      _command_mto name, src:src, target:target do |files, target|
        func.call files, target
      end
  else
    _command name do ||
      func.call
    end
  end
end

# Register a new beaver command
def _command(name, &func)
  $beaver.__appendCommand(name, func)
end

# Defines a dependency from source file to target file
OneWayDependency = Struct.new(:src, :target)

# - Example:
# ```ruby
# command_oto :command_name, src: "src/**/*.c", target_dir: "build", target_ext: ".o" do |source_file, target_file|
# 
# end
# ```
def _command_oto(name, src: nil, target_dir: nil, target_ext: nil, &func)
  $beaver.__appendCommandCB name do
    src_files = get_matches(src)
    
    abs_cd = File.dirname(File.expand_path($0))
    
    # Contains all files with (source and target)
    files = []
    src_files.each do |srcfile|
      file_name = File.basename(srcfile, ".*")
      
      # path of the source file relative to the current directory
      path_ext = File.dirname(
        Pathname.new(File.expand_path(srcfile))
          .relative_path_from(abs_cd)
      )
      
      files << OneWayDependency.new(
        srcfile,
        File.join(target_dir, path_ext, "#{file_name}#{target_ext}")
      )
    end
    
    for file in files
      should_execute = false
      if file_changed?(file.src)
        # If source file has changed, then the function should be called
        should_execute = true
      elsif !File.file?(file.target)
        # If the target file does not exist, then the function should be called
        should_execute = true
      elsif __beaver_file_changed?
        # If the beaver config file changed, then the function should be called
        should_execute = true
      end
    
      if should_execute
        func.call file.src, file.target
      end      
    end
  end
end


def _command_mto(name, src:nil, target:nil, &func)
  $beaver.__appendCommandCB name do
    should_execute = false
    
    if_any_changed src do |_|
      should_execute = true
    end
    
    if !File.file?(target)
      should_execute = true
    end
    
    if should_execute
      src_files = get_matches(src)
      func.call src_files.join(" "), target
    end
  end
end
