# Global file objects $file and $files

class SingleFile
  # Full file path e.g. "src/main.c"
  attr_accessor :path

  def initialize(path)
    @path = path
  end

  # the name of the file, without extension
  def name
    File.basename(@path, ".*")
  end

  # the file name and extension
  def full_name
    File.basename(@path)
  end

  # the file extension
  def ext
    File.extname(@path)
  end

  # the directory of the file e.g. if the file is "src/main.c", dir will be
  # "src"
  def dir
    File.dirname(@path)
  end

  # will return path
  def to_s
    @path
  end
end

class MultiFiles
  # an array of file paths
  attr_accessor :paths

  def initialize(paths)
    @paths = paths
  end

  # an array of all file names, without extensions
  def names
    @paths.map { |p| File.basename(p, ".*") }
  end

  # all file names, including their extensions
  def full_names
    @paths.map { |p| File.basename(p) }
  end

  # all file extensions
  # 
  # For a list of all unique extensions, use `$files.exts.uniq`
  def exts
    @paths.map { |p| File.extname(p) }
  end

  # all directories
  #
  # For a list of all unique directories, use `$files.dir.uniq`
  def dir
    @paths.map { |p| File.dirname(p) }
  end

  # loop over each file
  def each(&f)
    @paths.each do |p|
      f.call(p)
    end
  end

  # will return a space separated list of files, surrounded with quotes
  def to_s
    @paths.inject("") { |list, elem| list + " \"#{elem}\"" }.strip
  end
end

$file = nil
$files = nil

# Shorthand for using `$file` or `$files`
# def $f
#   return $file || $files
# end
