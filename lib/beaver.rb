module Beaver
  $beaver = nil if !$beaver.nil?
end

Dir.chdir(File.dirname($0))

require 'formatting/log'

require 'files/file_utils'
require 'files/cache'
require 'files/file_obj'

require 'command'
require 'context'
require 'project'
require 'target'
require 'sh'
require 'tools'
require 'envvar'

require 'common-language/library'

require 'c/dependency'
require 'c/target/target'
require 'c/target/library'
require 'c/target/executable'
require 'c/configuration'
require 'c/tools'
require 'c/pkg_config'

require 'swift/spm_project.rb'
require 'swift/target/spm_product.rb'
require 'swift/target/spm_library.rb'

include Beaver

