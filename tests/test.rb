require 'minitest/autorun'
require_relative 'common.rb'

###############################################################################

clean_all

require_relative 'basic-c-commands/test.rb'
require_relative 'basic-c-project/test.rb'
require_relative 'multi-project/test.rb'
require_relative 'multi-project-different-file/test.rb'
require_relative 'objc-project/test.rb'
require_relative 'swift-project/test.rb'

Minitest.after_run {
  clean_all
  if swift?
    Dir.chdir(File.join(__dir__, "swift-project", "TestPackage")) do
      system "swift package clean"
    end
  end
}

