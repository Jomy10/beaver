require 'rake'

Gem::Specification.new do |s|
  s.name = 'beaver'
  s.version = '0.1.0'
  s.summary = 'Ruby-powered build tool'
  s.authors = ["Jonas Everaert"]
  s.files = FileList['lib/**/*.rb'].exclude(*File.read('.gitignore').split).to_a
  s.homepage = 'https://github.com/jomy10/beaver'
  s.license = 'MIT'
end
