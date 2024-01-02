module Beaver
  $beaver = nil if !$beaver.nil?
end

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

require 'formatting/log'

require 'c/dependency'
require 'c/target'
require 'c/configuration'
require 'c/tools'
require 'c/pkg_config'

include Beaver

