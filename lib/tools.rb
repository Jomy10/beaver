module Beaver
  module Internal
    # Returns the first matching executable
    def determine_cmd(*cmds)
      exts = ENV["PATHEXT"] ? ENV["PATHEXT"].split(";") : [""]
      paths = ENV["PATH"].split(File::PATH_SEPARATOR)
      cmds.each do |cmd|
        paths.each do |path|
          exts.each do |ext|
            exe = File.join(path, "#{cmd}#{ext}")
            return exe if File.executable?(exe) && !File.directory?(exe)
          end
        end
      end
    end
  end
end

