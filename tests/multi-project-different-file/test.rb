class MultiProjectDifferentFile < Minitest::Test
  def setup
    Dir.chdir(__dir__) do
      clean
    end
  end
  
  EXPECTED_HELLO_ARTIFACTS = [
    "out/Other/Hello/libHello.a",
    "out/Other/Hello/libHello.so",
    "out/Other/Hello/libHello.pc",
    "out/Other/Hello/obj/static/src_lib.c.o",
    "out/Other/Hello/obj/dynamic/src_lib.c.o",
  ].sort
  
  def test_build_other
    Dir.chdir(__dir__) do
      system "ruby make.rb build Other/Hello"
      assert_equal 0, $?.exitstatus
      assert_equal EXPECTED_HELLO_ARTIFACTS,
        Dir["out/Other/**/*"].select { |f| !File.directory?(f) }
    end
  end
  
  def test_run_executable
    Dir.chdir(__dir__) do
      assert_equal "Hello world\n", `ruby make.rb run`
    end
  end
end

