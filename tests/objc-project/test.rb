class ProjectWithFramework < Minitest::Test
  def setup
    Dir.chdir(__dir__) do
      clean
    end
  end
  
  def test_run
    Dir.chdir(__dir__) do
      assert_match /\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}.\d{3} MyExecutable\[\d+:\d+\] Hello world\n/,
        `ruby make.rb run --no-verbose 2>&1`
    end
  end
end

