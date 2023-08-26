require 'rake'

Gem::Specification.new do |s|
  s.name = 'beaver-build'
  s.version = '2.2.0'
  s.summary = 'Ruby-powered build tool'
  s.description = %{Beaver is an easy to understand build tool with a lot of capabilities.
Documentation and examples on [github](https://github.com/jomy10/beaver).}
  s.authors = ["Jonas Everaert"]
  files = FileList['lib/**/*.rb'].exclude(*File.read('.gitignore').split).to_a
  files << "bin/beaver"
  s.files = files
  s.bindir = 'bin'
  s.executables << 'beaver'
  s.add_runtime_dependency 'msgpack', '~> 1.6.0'
  s.homepage = 'https://github.com/jomy10/beaver'
  s.license = 'MIT'
end
