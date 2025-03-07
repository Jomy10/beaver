# Helper for running the examples from the current directory

system "cargo build -p beaver-cli"

if $? != 0
  puts "error occured"
  exit($?.to_i)
end

beaver = "../../target/debug/beaver-cli"

Dir.chdir(File.join("examples", ARGV[0])) do
  exec "#{beaver} #{ARGV[1...].join(" ")}"
end
