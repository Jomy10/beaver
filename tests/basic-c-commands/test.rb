class BasicCCommand < Minitest::Test
  def setup
    Dir.chdir(__dir__) do
      clean
    end
  end

  def test_build_default_command
    Dir.chdir(__dir__) do
      system "OUT=out ruby make.rb"
      assert_equal 0, $?.exitstatus
      assert_equal ["out/obj/hello.o", "out/obj/main.o"], Dir["out/obj/*.o"]
    end
  end

  def test_cache
    Dir.chdir(__dir__) do
      system "OUT=out ruby make.rb"
      assert_equal 0, $?.exitstatus
      assert_equal "", `OUT=out ruby make.rb build`
      assert_equal "Building object\nBuilding object\nLinking\n", `OUT=out ruby make.rb build -f`
      assert_equal 0, $?.exitstatus
    end
  end

  def test_file_cache
    Dir.chdir(__dir__) do
      system "OUT=out ruby make.rb"
      assert_equal 0, $?.exitstatus
      FileUtils.rm_r "out/obj/main.o"
      assert_equal "Building object\nBuilding object\nLinking\n", `OUT=out ruby make.rb build -f`
      assert_equal 0, $?.exitstatus
      system "touch src/main.c"
      assert_equal "Building object\nBuilding object\nLinking\n", `OUT=out ruby make.rb build -f`
      assert_equal 0, $?.exitstatus
      assert_equal "", `OUT=out ruby make.rb build`
      assert_equal 0, $?.exitstatus
    end
  end

  def test_run
    Dir.chdir(__dir__) do
      system "OUT=out ruby make.rb"
      assert_equal 0, $?.exitstatus
      assert_equal "Hello world!", `OUT=out ruby make.rb run`
      assert_equal 0, $?.exitstatus
    end
  end

  def test_no_env_var_given
    Dir.chdir(__dir__) do
      assert_equal "[ERR] OUT not given\n", `ruby make.rb run 2>&1`
      assert_equal 1, $?.exitstatus
    end
  end
end

