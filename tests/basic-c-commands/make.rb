require 'beaver'

env :OUT, ""
env :CC, "clang"

if OUT == ""
  Log::err("OUT not given")
end

OBJ_OUT = File.join(OUT, "obj")
Beaver::def_dir OBJ_OUT

EXEC_NAME = "hello"

cmd :build do
  call :build_objs
  call :link
end

cmd :build_objs, each(["src/main.c", "src/hello.c"]), out: proc { |f| File.join(OBJ_OUT, f.basename + ".o") } do |file, outfile|
  sh %(#{CC} -c #{file} -o #{outfile})
end

cmd :link, all(File.join(OBJ_OUT, "*.o")), out: EXEC_NAME do |files, outfile|
  sh %(#{CC} #{files} -o #{outfile})
end

cmd :run do
  sh %(./#{EXEC_NAME})
end

