class MultiProject < Minitest::Test
  def setup
    Dir.chdir(__dir__) do
      clean
    end
  end
  
  def test_run
    Dir.chdir(__dir__) do
      assert_match "Hello world!\n", `ruby make.rb run`
    end
  end
end

