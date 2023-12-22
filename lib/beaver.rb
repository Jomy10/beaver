# todo: ch dirname($1)


module Beaver
  $beaver = nil
end

require 'files/file_utils'
require 'files/cache'
require 'files/file_obj'
require 'context'
require 'project'
require 'target'
require 'command'
require 'sh'
require 'formatting/log'

require 'c/target'
require 'c/configuration'

include Beaver

