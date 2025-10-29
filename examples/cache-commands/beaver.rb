Project(name: "Test")

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
