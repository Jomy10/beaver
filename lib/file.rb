#########
# Cache #
#########

require 'msgpack'

FileInfo = Struct.new(:modified)

# - file_info: { command => file_name => file_info }
Files = Struct.new(:commands) do
  # returns the modified date of the file, or nil if it is not yet known
  def modified(cmd, file)
    files_info = commands[cmd.to_s]
    if files_info.nil?
      return nil
    end
    fi = files_info[file]
    if fi.nil?
      nil
    else
      fi.modified
    end
  end

  def add(cmd, path)
    files_info = commands[cmd.to_s]
    if files_info.nil?
      commands[cmd.to_s] = Hash.new
      files_info = commands[cmd.to_s]
    end
    files_info[path] = FileInfo.new(
      File.mtime(path).to_i # modified date as unix time stamp
    )
  end
end

MessagePack::DefaultFactory.register_type(
      0x01,
      Files,
      packer: ->(files, packer) {
        packer.write(files.commands)
      },
      unpacker: ->(unpacker) {
        Files.new(unpacker.read)
      },
      recursive: true,
)

MessagePack::DefaultFactory.register_type(
      0x02,
      FileInfo,
      packer: ->(fi, packer) {
        packer.write(fi.modified)
      },
      unpacker: ->(unpacker) {
        FileInfo.new(unpacker.read)
      },
      recursive: true
)

# f = Files.new(Hash.new)
# f.add("lib/beaver.rb")
# pack = msg = MessagePack.pack(f)
# p pack
# p MessagePack::unpack(pack)

class CacheManager
  attr_accessor :files
  
  def initialize
    begin
      @files = MessagePack::unpack(File.read $beaver.file_cache_file)
    rescue EOFError
      @files = Files.new(Hash.new)
      @files.add("__BEAVER__CONFIG__", $PROGRAM_NAME)
    end
  end

  def save
    packed = MessagePack.pack(@files)
    unless Dir.exist? $beaver.cache_loc
      Dir.mkdir $beaver.cache_loc
    end
    File.binwrite($beaver.file_cache_file, packed)
  end
end

$cache = nil # will be initialized in `$beaver.end`, so that all settings are applied first

def reset_cache
  $cache.files = Files.new(Hash.new)
  $cache.files.add("__BEAVER__CONFIG__", $PROGRAM_NAME)
end

##############
# File utils #
##############

# Returns wether a file has changed
# Also returns true if no information about file changes is found
def changed? cmd_ctx, file
  cached_modified = $cache.files.modified cmd_ctx, file

  if cached_modified.nil?
    # probably new file
    return true
  end
  
  last_modified = File.mtime(file).to_i
  if cached_modified < last_modified
    return true
  else
    return false
  end
end
