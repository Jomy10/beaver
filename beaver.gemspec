require 'rake'

Gem::Specification.new do |s|
  s.name = 'beaver'
  s.version = '3.0.0'
  s.summary = "build system"
  s.description =  %{Beaver is an easy to understand build tool with a lot of capabilities. Documentation and examples on [github](https://github.com/jomy10/beaver).}
  s.homepage = "https://github.com/jomy10/beaver"
  s.license = "MIT"
  s.authors = ["Jonas Everaert"]
  s.files = FileList['lib/**/*.rb']
  s.add_runtime_dependency 'fileutils', '~> 1.7'
  # s.add_runtime_dependency 'colorize', '~> 1.1'
  s.add_runtime_dependency 'workers', '~> 0.6'
  s.add_runtime_dependency 'rainbow', '~> 3.1'
  s.add_runtime_dependency 'msgpack', '~> 1.6'
end

