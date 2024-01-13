# Builds and uploads docker images
#
# To build your own image, use:
# ruby make.rb build [image_name]
#

require 'beaver'

env :CONTAINER_MANAGER, "podman"

$beaver.set_options_callback do |opt|
  opt.on("--push", "Push dockerfiles")
end

image_files = Dir["*.dockerfile"]

platforms = [
  "linux/amd64",
  "linux/arm64",
  "linux/riscv64",
  "linux/ppc64le",
  "linux/s390x",
  "linux/386",
  "linux/mips64le",
  "linux/mips64",
  "linux/arm/v7",
  "linux/arm/v6"
]

def build_image(name, os, tag, platforms, file)
  sh "#{CONTAINER_MANAGER} buildx build " +
    "#{($beaver.options[:push] && CONTAINER_MANAGER != "podman") ? "--push" : ""} " +
    "--platform #{platforms.join(",")} " +
    "--tag jomy10/#{name}:#{os}-#{tag} " +
    "-f #{file} " +
    "."
  if CONTAINER_MANAGER == "podman"
    sh "buildah push"
  end
end

cmd :build do
  arg = $beaver.options[:args][1]
  if arg == nil
    puts "No command specified"
    exit 1
  end
  if arg == "all"
    call :build_images
  else
    build_image("beaver", arg, "latest", platforms, arg + ".dockerfile")
  end
end

cmd :build_images, each(image_files.filter { |f| !File.empty? f }) do |file|
  build_image("beaver", file.basename, "latest", platforms, file)
end

