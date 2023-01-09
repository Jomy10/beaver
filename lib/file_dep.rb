require 'file_obj'

# File dependencies for commands
class FileDep
  attr_accessor :type
  
  def initialize(glob, type)
    # Can be a string like "main.c" or "src/*.c", or an array like
    # ["src/main.c", "src/lib/*.c"]
    @glob = glob
    # :each or :all
    @type = type
    # SingleFile, or MultiFile
    @file_obj = nil
  end

  # Run fn for each file, passing the file name to fn
  def each_file(&fn)
    # Check if already a file object collected
    if !@file_obj.nil?
      if @type == :each
        # @file_obj = []SingleFile
        @file_obj.each do |file_o|
          fn.call(file_o.path)
        end
      else
        # @file_obj = MultiFiles
        @file_obj.each do |file|
          fn.call(file)
        end
      end

      return
    end

    # Collect the file object
    
    # initialize files as an empty array. This will contain full paths to
    # files, which well then be put into @file_obj as either a []SingleFile
    # or MultiFiles
    files = []
    
    globs = nil
    if @glob.respond_to? :each
      # array
      globs = glob
    else
      # string
      globs = [@glob]
    end

    globs.each do |glob|
      Dir[glob].each do |file|
        fn.call(file)
        files << file
      end
    end

    # set the @file_obj
    if @type == :each
      @file_obj = files.map { |file| SingleFile.new file }
    else
      @file_obj = MultiFiles.new files
    end
  end

  # retuns the file/files object(s)
  # will return either []SingleFile or MultiFiles
  def files
    if @file_obj.nil?
      # Collect file_obj first
      self.each_file { |f| }
    end

    return @file_obj
  end
end

# Command will be called for each file
def each(dep)
  return FileDep.new dep, :each
end

# Command will be called for all files at once
def all(dep)
  return FileDep.new dep, :all
end
