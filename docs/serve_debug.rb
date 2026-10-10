# Start a debug server and rebuild documentation on file changes
# Usage: `ruby serve_debug.rb`

require "webrick"
require "listen"
require "open3"

ignore = [
  %r{_build(?:/|$)},
  %r{.venv(?:/|$)},
  %r{serve_debug\.rb}
]

listener = Listen.to(".", ignore: ignore) do |modified, added, removed|
  puts(modified: modified, added: added, removed: removed)
  system("beaver build")
end

listener.start

server = WEBrick::HTTPServer.new(
  Port: 8000,
  DocumentRoot: "_build/html"
)

system("beaver build")

server.start
