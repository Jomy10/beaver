class BasicCCommandTest < Minitest::Test
  def setup
    Dir.chdir(__dir__) do
      # FileUtils.rm("out")
    end
  end

  def test_build_default_command
    Dir.chdir(__dir__) do
      system "pwd"
      system "OUT=out ruby make.rb"
      assert_equal ["out/obj/hello.o", "out/obj/main.o"], Dir["out/obj/*.o"]
    end
  end

  def test_run
    Dir.chdir(__dir__) do
      assert_equal "Hello world!", `OUT=out ruby make.rb run`
    end
  end

  def test_no_env_var_given
    Dir.chdir(__dir__) do
      assert_equal "[ERR] OUT not given\n", `ruby make.rb run 2>&1`
    end
  end
end

