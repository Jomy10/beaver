class Swift < Minitest::Test
  def setup
    Dir.chdir(__dir__) do
      clean
      Dir.chdir("TestPackage") do
        system "swift package clean"
      end
    end
  end

  def test_run
    skip if linux? && !swift?
    Dir.chdir(__dir__) do
      assert_match /.*Hello from swift!\n$/, `ruby make.rb run`
    end
  end

  def test_run_swift_executable
    skip if !swift?
    Dir.chdir(__dir__) do
      assert_match /.*Running a swift executable from beaver\n$/, `ruby make.rb run TestPackage/TestExecutable`
    end
  end
end

