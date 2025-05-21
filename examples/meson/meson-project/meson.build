project('MesonProject', 'c')

public_headers = include_directories('.')

target = static_library(
  'library',
  'source.c',
  include_directories: public_headers
)

pkgconfig = import('pkgconfig')
pkgconfig.generate(
  libraries: [target],
  subdirs: ['.'],
  version: '1.0',
  name: 'liblibrary',
  filebase: 'library',
  description: 'my library'
)
