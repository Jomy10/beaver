class BasicCProject < Minitest::Test
  def setup
    clean
  end

  EXPECTED_MY_LIBRARY_ARTIFACTS = [
    "out/MyLibrary/libMyLibrary.a",
    "out/MyLibrary/libMyLibrary.pc",
    "out/MyLibrary/obj/static/lib_greet.c.o",
    "out/MyLibrary/obj/static/lib_person.c.o"
  ].sort

  EXPECTED_MY_EXECUTABLE_ARTIFACTS = [
    "out/MyExecutable/obj/bin_main.c.o",
    "out/MyExecutable/obj/bin_print.cpp.o",
    "out/MyExecutable/MyExecutable"
  ].sort
  
  def test_build_library
    Dir.chdir(__dir__) do
      system "ruby make.rb build MyLibrary"
      assert_equal 0, $?.exitstatus
      assert_equal EXPECTED_MY_LIBRARY_ARTIFACTS,
        Dir["out/**/*"].select { |f| !File.directory?(f) }
    end
  end

  def test_build_executable
    Dir.chdir(__dir__) do
      # Expected artifacts
      system "ruby make.rb build MyExecutable"
      assert_equal 0, $?.exitstatus
      assert_equal [*EXPECTED_MY_LIBRARY_ARTIFACTS, *EXPECTED_MY_EXECUTABLE_ARTIFACTS].sort,
        Dir["out/**/*"].select { |f| !File.directory?(f) }
      
      assert_equal "Hello John Doe!\nGOOD\n", `./out/MyExecutable/MyExecutable`
      assert_equal 0, $?.exitstatus
    end
  end
end

