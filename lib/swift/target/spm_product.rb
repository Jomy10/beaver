module Swift
  class SPMProduct < Struct.new(
    :name,
    # Library-specific #
    # Valid values are: :static, :dynamic
    # [Symbol | Symbol[]] (or anything that converts into a symbol)
    :type,
    :flags,
    :project,
    keyword_init: true
  )
    include Beaver::Internal::PostInitable
    include Beaver::Internal::Target

    def out_dir
      File.join(self.project.build_dir, self.project.config_name)
    end

    def abs_out_dir
      if File.absolute_path? self.project.build_dir
        self.out_dir
      else
        File.join(self.project.base_dir, self.out_dir)
      end
    end

    def self.library(name:,type:, project: nil)
      SPMLibrary.new(name: name, type: type, project: project)
    end

    def self.executable(name:, project: nil)
      SPMExecutable.new(name: name, project: project)
    end

    private
    def _custom_after_init
      self.flags = self.flags || []
    end
  end
end

