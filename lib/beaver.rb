module Beaver
  $beaver = nil if !$beaver.nil?
end

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

require 'c/dependency'
require 'c/target/target'
require 'c/target/library'
require 'c/target/executable'
require 'c/configuration'
require 'c/tools'
require 'c/pkg_config'

include Beaver

