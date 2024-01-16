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
    Dir.chdir(__dir__) do
      assert_match /.*Hello from swift!\n$/, `ruby make.rb run`
    end
  end
end

