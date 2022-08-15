# Gemfile for RubyGems
  
require 'rake'

Gem::Specification.new do |s|
  s.name = 'beaver-build'
  s.version = '0.1.0'
  s.summary = 'Ruby-powered build tool'
  s.description = %{Beaver is an easy to understand build tool with a lot of capabilities.
Documentation and examples on [github](https://github.com/jomy10/beaver) (https://github.com/jomy10/beaver).}
  s.authors = ["Jonas Everaert"]
  s.files = FileList['lib/**/*.rb'].exclude(*File.read('.gitignore').split).to_a
  s.homepage = 'https://github.com/jomy10/beaver'
  s.license = 'MIT'
end
