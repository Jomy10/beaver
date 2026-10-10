build_dir "_build/beaver"

venv_dir = "./.venv"

python = opt("python", default: "python3")

sh "#{python} -m venv #{venv_dir}" if !Dir.exist? venv_dir

py = %w[
  Scripts/python.exe
  bin/python
  bin/python3
]
  .map { |path| File.join(venv_dir, path) }
  .find { |path| File.file? path }

abort "Python interpreter not found in #{venv}" unless py

def pip(py, package, import_name=nil)
  check_package = <<EOF
try:
  import #{import_name || package}
  print(1)
except ImportError as e:
  print(0)
EOF

  if (`#{py} -c "#{check_package}"`).strip == "0"
    sh py, "-m", "pip", "install", package
  end
end

pip(py, "git+https://github.com/Jomy10/rubydomain", "sphinxcontrib.rubydomain")
pip(py, "shibuya")

# check_package = <<EOF
# try:
#   import sphinxcontrib.rubydomain
#   print(1)
# except ImportError as e:
#   print(0)
# EOF
# if (`#{py} -c "#{check_package}"`).strip == "0"
#   # sh py, "-m", "pip", "install", "sphinxcontrib-rubydomain"
#   sh py, "-m", "pip", "install", "git+https://github.com/Jomy10/rubydomain"
# end

format = opt "format", "f", default: "html"

cmd "build" do
  sh py, "-m", "sphinx", "-M", format, ".", "_build"
end
