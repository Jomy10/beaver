require 'msgpack'
require 'workers'

module Beaver
  module Internal
    # Project impl
    class CacheManager
      # { project => elements }
      attr_accessor :cache

      DEFAULT_PROJECT = "__BEAVER_BASE"
      
      def initialize
        @cache = Hash.new
      end
      
      def project_cache_location(project_name)
        return File.join($beaver.cache_dir, "project_#{project_name}.cache")
      end
      
      # Get the project cache for the project with the specified name.
      # Creates a new entry if the project cache was empty
      def get_project_cache(_project_name)
        project_name = _project_name
        if _project_name.nil?
          project_name = DEFAULT_PROJECT
        end
        if @cache[project_name].nil?
          project_cache_file = self.project_cache_location(project_name)
          if File.exists?(project_cache_file)
            @cache[project_name] = MessagePack::unpack(File.read(project_cache_file))
            return @cache[project_name]
          else
            return nil
          end
        else
          return @cache[project_name]
        end
      end
      
      def save
        for project_name, project_cache in @cache
          file_path = self.project_cache_location(project_name)
          packed = MessagePack.pack(project_cache)
          File.binwrite(file_path, packed)
        end
      end
      
      private
      def add_project_cache_if_needed(_project_name)
        project_name = _project_name
        if _project_name.nil?
          project_name = DEFAULT_PROJECT
        end
        if @cache[project_name].nil?
          project_cache_file = self.project_cache_location(project_name)
          if File.exists?(project_cache_file)
            @cache[project_name] = MessagePack::unpack(File.read(project_cache_file))
          else
            @cache[project_name] = Hash.new
          end
        end
      end
    end
    
    # Project > Commands implementation
    class CacheManager
      # :cache
      # ------
      # {
      #   project1 => {
      #     command1 => {
      #       :type,
      #       :input => { path: String, modified: Integer },
      #     }
      #   }
      # }
       
      def get_command_cache(command)
        if command.type == CommandType::NORMAL
          return nil
        end
        
        project_cache = self.get_project_cache(command.project.name)
        if project_cache.nil? || project_cache[command.name].nil?
          return nil
        end
        return project_cache[command.name]
      end
      
      # Overwrites any existing cache
      def add_command_cache(command)
        command_type = command.type
        if command_type == CommandType::NORMAL
          return
        end
        
        self.add_project_cache_if_needed(command.project.name)
        self.add_command_cache_if_needed(command.project.name, command.name)
        command_cache = self.get_command_cache(command)
        case command_type
        when CommandType::EACH
          command_cache[:type] = CommandType::EACH
          input_files = command.input_files
          command_cache[:input] = input_files.map { |f| { path: f, modified: File.mtime(f).to_i } }
        when CommandType::ALL
          command_cache[:type] = CommandType::ALL
          command_cache[:input] = command.input_files.map { |f| { path: f, modified: File.mtime(f).to_i } }
        end
      end
      
      private
      def add_command_cache_if_needed(_project_name, command_name)
        project_name = _project_name
        if _project_name.nil?
          project_name = DEFAULT_PROJECT
        end
        if @cache[project_name][command_name].nil?
          @cache[project_name][command_name] = Hash.new
        end
      end
    end
    
    # Project > base config file impl
    class CacheManager
      # {
      #   project => {
      #     __BEAVER_BASE_CONFIG_FILE => {
      #       file1 => {
      #         :path, :modified
      #       }
      #     }
      #   }
      # }
      
      CONFIG_BASE = "__BEAVER_BASE_CONFIG_FILE"
      
      def get_config_cache
        project_cache = self.get_project_cache(nil)
        if project_cache.nil? || project_cache[CONFIG_BASE].nil?
          return nil
        end
        return project_cache[CONFIG_BASE]
      end
      
      def add_config_cache
        base_file = File.basename($0)
        self.add_project_cache_if_needed(nil)
        self.add_command_cache_if_needed(nil, CONFIG_BASE)
        command_cache = self.get_config_cache
        for file in [base_file] # TODO: requires
          command_cache[file] = {
            path: file,
            modified: File.mtime(file).to_i
          }
        end
      end
    end
  end
end

