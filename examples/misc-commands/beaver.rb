Project(name: "Test")

pre "build" do
  if files_changed("input.txt")
    puts "input.txt changed, do something with it"
  end
end
