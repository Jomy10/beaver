require "minitest/autorun"
require "open3"
require "fileutils"
require "rbconfig"

base_dir = File.join(__dir__, "..")
Dir.chdir(base_dir)

$beaver = File.join(base_dir, "target/release/beaver")

def exec(exe, dir, *args)
    Open3.capture3({"BEAVER_LOG" => "info"}, exe, *args, chdir: dir)
end

def beaver(dir, *args)
    exec($beaver, dir, *args)
end

def clean_build dir
    FileUtils.rm_r(File.join(dir, "build")) if File.exist?(File.join(dir, "build"))
end

# Checks if an executable links to a specific dynamic library
def links_to_lib?(exe_path, dir, libname)
    case RbConfig::CONFIG["host_os"]
    when /darwin/
        stdout, stderr, status = exec("otool", dir, "-L", exe_path)
        assert status.success?, stderr
        stdout.include? libname
    when /linux/
        stdout, stderr, status = exec("ldd", dir, exe_path)
        assert status.success?, stderr
        stdout.include? libname
    when /mswin|msys|mingw|cygwin|win32|win64/
        stdout, stderr, status = exec("ldd", dir, exe_path)
        assert status.success?, stderr
        stdout.include? libname
    else
        false
    end
end

describe "examples" do
    describe "c-project" do
        dir = File.join(base_dir, "examples/c-project")
        raise "dir does not exist" unless Dir.exist? dir

        clean_build(dir)

        it "compiles and runs" do
            stdout, stderr, status = beaver(dir)

            assert status.success?, stdout + stderr

            stdout, stderr, status = exec(File.join(dir, "build", "debug", "HelloWorld"), dir)

            assert status.success?, stderr
            _(stdout).must_equal("Hello world!\n")
        end

        Minitest.after_run do
            clean_build(dir)
        end
    end

    describe "cache-commands" do
        dir = File.join(base_dir, "examples/cache-commands")
        raise "dir does not exist" unless Dir.exist? dir

        clean_build(dir)
        File.write(File.join(dir, "input.txt"), "tihi, you found me\n")

        it "works" do
            expected_to_recompile = proc {
                while true
                    stdout, stderr, status = beaver(dir)

                    if status.success?
                        assert_includes stdout.lines, "ok\n"

                        # Recompile -> not executed again
                        stdout, stderr, status = beaver(dir)
                        assert status.success?, stdout + stderr
                        refute_includes stdout.lines, "ok\n"
                        break
                    else
                        assert_includes stderr.lines, "failed\n"
                    end
                end
            }

            expected_to_recompile.()



            # Recompile when file changes
            File.write(File.join(dir, "input.txt"), "tihi, you found me again!\n")
            expected_to_recompile.()
        end

        Minitest.after_run do
            clean_build(dir)
            File.write(File.join(dir, "input.txt"), "tihi, you found me\n")
        end
    end

    describe "arguments" do
        dir = File.join(base_dir, "examples/arguments")
        raise "dir does not exist" unless Dir.exist? dir

        clean_build(dir)

        it "puts hello world" do
            stdout, stderr, status = beaver(dir, "helloWorld")
            assert status.success?, stdout + stderr
            _(stdout).must_equal("Hello world\n")
        end

        it "puts hello world default" do
            stdout, stderr, status = beaver(dir)
            assert status.success?, stdout + stderr
            _(stdout).must_equal("Hello world\n")
        end

        it "puts hello world shell" do
            stdout, stderr, status = beaver(dir, "shellCommand")
            assert status.success?, stdout + stderr
            _(stdout).must_equal("Hello world!\nHello world!\n")
            stderr = stderr.lines.map { |l| l.strip }.join("\n")
            _(stderr).must_equal("echo 'Hello world!'\n#{`which echo`.strip} \"Hello world!\"")
        end

        it "puts 2" do
            stdout, stderr, status = beaver(dir, "printArg", "--", "--argument-name", "sdl-version")
            assert status.success?, stdout + stderr
            _(stdout).must_equal("2\n")
        end

        it "puts 3" do
            stdout, stderr, status = beaver(dir, "printArg", "--", "--argument-name", "sdl-version", "--sdl-version", "3")
            assert status.success?, stdout + stderr
            _(stdout).must_equal("3\n")
        end

        it "puts 3 with small arg" do
            stdout, stderr, status = beaver(dir, "printArg", "--", "--argument-name", "sdl-version", "-s", "3")
            assert status.success?, stdout + stderr
            _(stdout).must_equal("3\n")
        end

        it "puts flag" do
            stdout, stderr, status = beaver(dir, "printArg", "--", "--argument-name", "from-source")
            assert status.success?, stdout + stderr
            _(stdout).must_equal("false\n")
        end

        it "puts flag set" do
            stdout, stderr, status = beaver(dir, "printArg", "--", "--argument-name", "from-source", "--from-source")
            assert status.success?, stdout + stderr
            _(stdout).must_equal("true\n")
        end

        it "puts flag default nil" do
            stdout, stderr, status = beaver(dir, "printArg", "--", "--argument-name", "warn")
            assert status.success?, stdout + stderr
            _(stdout).must_equal("\n")
        end

        it "puts flag default set" do
            stdout, stderr, status = beaver(dir, "printArg", "--", "--argument-name", "warn", "-w")
            assert status.success?, stdout + stderr
            _(stdout).must_equal("true\n")
        end

        it "puts flag default negated" do
            stdout, stderr, status = beaver(dir, "printArg", "--", "--argument-name", "warn", "--no-warn")
            assert status.success?, stdout + stderr
            _(stdout).must_equal("false\n")
        end

        Minitest.after_run do
            clean_build(dir)
        end
    end

    describe "cargo" do
        dir = File.join(base_dir, "examples/cargo")
        raise "dir does not exist" unless Dir.exist? dir

        clean_build(dir)

        it "compiles and runs" do
            stdout, stderr, status = beaver(dir)
            assert status.success?, stdout + stderr

            stdout, stderr, status = exec(File.join(dir, "build", "debug", "TestCargo"), dir)
            assert status.success?, stderr
            _(stdout).must_equal("Hello world\n")
        end

        Minitest.after_run do
            clean_build(dir)
        end
    end

    describe "cmake" do
        dir = File.join(base_dir, "examples/cmake")
        raise "dir does not exist" unless Dir.exist? dir

        clean_build(dir)

        it "compiles and runs" do
            stdout, stderr, status = beaver(dir)
            assert status.success?, stdout + stderr

            stdout, stderr, status = exec(File.join(dir, "build", "debug", "MyFileFormat"), dir)
            assert status.success?, stderr
            _(stdout).must_equal("Tests passed successfully!\n")
        end

        Minitest.after_run do
            clean_build(dir)
        end
    end

    describe "custom-target" do
        dir = File.join(base_dir, "examples/custom-target")
        raise "dir does not exist" unless Dir.exist? dir

        clean_build(dir)

        it "compiles and runs" do
            stdout, stderr, status = beaver(dir)
            assert status.success?, stdout + stderr

            stdout, stderr, status = exec(File.join(dir, "build", "debug", "Test"), dir)
            assert status.success?, stdout + stderr
        end

        Minitest.after_run do
            clean_build(dir)
        end
    end

    describe "dependencies" do
        dir = File.join(base_dir, "examples/dependencies")
        raise "dir does not exist" unless Dir.exist? dir

        clean_build(dir)

        it "compiles and runs" do
            stdout, stderr, status = beaver(dir)
            assert status.success?, stdout + stderr

            exe = File.join(dir, "build", "debug", "MyExecutable")
            assert(links_to_lib? exe, dir, "libMyMathLibrary")

            stdout, stderr, status = exec(exe, dir)
            assert status.success?, stdout + stderr
            _(stdout).must_equal("1 + 2 = 3\nuuid_is_null = 1\n");
        end

        Minitest.after_run do
            clean_build(dir)
        end
    end

    describe "meson" do
        dir = File.join(base_dir, "examples/meson")
        raise "dir does not exist" unless Dir.exist? dir

        clean_build(dir)

        it "compiles and runs" do
            stdout, stderr, status = beaver(dir)
            assert status.success?, stdout + stderr

            exe = File.join(dir, "build", "debug", "test")
            assert File.exist?(exe), stdout + stderr

            stdout, stderr, status = exec(exe, dir)
            assert status.success?, stdout + stderr
            _(stdout).must_equal("Test passed\n");
        end

        Minitest.after_run do
            clean_build(dir)
        end
    end

    describe "multi-project" do
        dir = File.join(base_dir, "examples/multi-project")
        raise "dir does not exist" unless Dir.exist? dir

        clean_build(dir)

        it "compiles and runs" do
            stdout, stderr, status = beaver(dir)
            assert status.success?, stdout + stderr

            exe = File.join(dir, "build", "debug", "Main")
            assert File.exist?(exe), stdout + stderr

            stdout, stderr, status = exec(exe, dir)
            assert status.success?, stdout + stderr
            _(stdout).must_equal("cmp = 0\nbuffer = [INFO] Hello world\n");
        end

        Minitest.after_run do
            clean_build(dir)
        end
    end

    describe "objc" do
        dir = File.join(base_dir, "examples/objc")
        raise "dir does not exist" unless Dir.exist? dir

        clean_build(dir)

        it "compiles and runs" do
            stdout, stderr, status = beaver(dir)
            assert status.success?, stdout + stderr

            exe = File.join(dir, "build", "debug", "hello_objc")
            assert File.exist?(exe), stdout + stderr

            stdout, stderr, status = exec(exe, dir)
            assert status.success?, stdout + stderr
            _(stderr).must_include("Hello Beaver");
        end

        Minitest.after_run do
            clean_build(dir)
        end
    end

    describe "phase-hooks" do
        dir = File.join(base_dir, "examples/phase-hooks")
        raise "dir does not exist" unless Dir.exist? dir

        clean_build(dir)

        it "compiles and runs" do
            stdout, stderr, status = beaver(dir)
            assert status.success?, stdout + stderr

            generated_h = File.join(dir, "build", "generated", "generated.h")

            _(stdout).must_include "Generating header..."
            _(stdout).must_include "I can also run after a phase!"

            exe = File.join(dir, "build", "debug", "ExeUsingGeneretedFile")
            assert File.exist?(exe), stdout + stderr

            stdout, stderr, status = exec(exe, dir)
            assert status.success?, stdout + stderr
            _(stdout).must_equal("I AM GENERATED\n");

            assert File.exist?(generated_h)
            stdout, stderr, status = beaver(dir, "clean")
            assert status.success?, stdout + stderr
            assert !File.exist?(generated_h)
        end

        Minitest.after_run do
            clean_build(dir)
        end
    end

    describe "spm" do
        dir = File.join(base_dir, "examples/spm")
        raise "dir does not exist" unless Dir.exist? dir

        clean_build(dir)

        it "compiles and runs" do
            stdout, stderr, status = beaver(dir)
            assert status.success?, stdout + stderr

            exe = File.join(dir, "build", "debug", "uses-swift")
            assert File.exist?(exe), stdout + stderr

            stdout, stderr, status = exec(exe, dir)
            assert status.success?, stdout + stderr
            _(stdout).must_include("Hello ");
        end

        Minitest.after_run do
            clean_build(dir)
        end
    end
end
