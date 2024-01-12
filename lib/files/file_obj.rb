module Beaver
  SingleFile = Struct.new(:path) do
    def basename
      File.basename(self.path, ".*")
    end
    
    def name
      File.basename(self.path)
    end
    
    def ext
      File.extname(self.path)
    end
    
    def dirname
      File.dirname(self.path)
    end
    
    def to_s
      "\"#{self.path}\""
    end
    
    def to_str
      self.path
    end
  end
  
  MultipleFiles = Struct.new(:paths) do
    def basenames
      self.paths.map { |p| File.basename(p, ".*") }
    end
    
    def name
      self.paths.map { |p| File.basename(p) }
    end
    
    def exts
      self.paths.map { |p| File.extname(p) }
    end
    
    def dirnames
      self.paths.map { |p| File.dirname(p) }
    end
    
    def each(&f)
      self.paths.each do |p|
        f.call(p)
      end
    end
    
    def to_s
      self.paths.inject("") { |list, elem| list + " \"#{elem}\"" }.strip
    end
    
    def to_str
      self.path
    end
  end
end

