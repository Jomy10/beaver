module Beaver
  class SPMProject < Project
    require 'json'

    def initialize(path:, &options)
      # TODO: caching project definition
      json = nil
      Dir.chdir(path) do
        json = `swift package dump-package`
        if $?.exitstatus != 0
          Beaver::Log::err("Couldn't parse swift package definition")
        end
      end

      pkg = JSON.parse(json)
      @name = pkg["name"]
      @base_dir = File.realpath(path)
      @build_dir = ".build"
      @configurations = {
        "debug" => {},
        "release" => {},
      }
      @default_config = nil # TODO: set to "debug", but currently doesn't work
      @current_config = nil
      @_options_callback = options
      $beaver.current_project = self
      $beaver.add_project(self)
      @targets = Hash.new

      pkg["products"].each do |target|
        if target["type"].include?("library")
          types = []
          for type in target["type"]["library"]
            case type
            when "automatic"
              types << :static
              types << :dynamic
            when "static"
              types << :static
            when "dynamic"
              types << :dynamic
            end
          end
          Swift::SPMProduct.library(name: target["name"], type: types, project: self)
        elsif target["type"].include?("executable")
          Swift::SPMProduct.executable(name: target["name"], project: self)
        end
      end
    end
  end
end

