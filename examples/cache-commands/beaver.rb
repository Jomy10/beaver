Project(name: "Test")

p get("command failed")

pre "build" do
  if files_changed("input.txt") || get("command failed") == "true"
    begin
      fn = [proc { puts "ok" }, proc { raise "failed" }][rand(2)]
      fn.()
      store("command failed", false)
    rescue => e
      store("command failed", true)
      raise e
    end
  end
end
