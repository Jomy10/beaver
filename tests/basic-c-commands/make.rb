require 'beaver'

env :OUT, ""
env :CC, "clang"

if OUT == ""
  Log::err("OUT not given")
end

OBJ_OUT = File.join(OUT, "obj")
Beaver::def_dir OBJ_OUT

EXEC_NAME = "hello" + ((/cygwin|mswin|mingw|bccwin|wince|emx/ =~ RUBY_PLATFORM) ? ".exe" : "")

cmd :build do
  call :build_objs
  call :link
end

cmd :build_objs, each(["src/main.c", "src/hello.c"]), out: proc { |f| File.join(OBJ_OUT, f.basename + ".o") } do |file, outfile|
  puts "Building object"
  sh %(#{CC} -c #{file} -o #{outfile})
end

cmd :link, all(File.join(OBJ_OUT, "*.o")), out: File.join(OUT, EXEC_NAME) do |files, outfile|
  puts "Linking"
  sh %(#{CC} #{files} -o #{outfile})
end

cmd :run do
  sh File.join("./", OUT, EXEC_NAME )
end

