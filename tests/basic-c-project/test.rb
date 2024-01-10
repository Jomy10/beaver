class BasicCProject < Minitest::Test
  def self.cleanup
    Dir.chdir(__dir__) do
      ignore_exception { FileUtils.rm_r("out") }
    end
  end
end

