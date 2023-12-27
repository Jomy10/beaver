module Beaver
  module C
    module Internal
      def get_cc
        # https://cmake.org/pipermail/cmake/2013-March/053819.html
        ENV["CC"] || Beaver::Internal::determine_cmd("cc", "clang", "gcc", "cl", "bcc", "xlc")
      end
      
      def get_cxx
        ENV["CXX"] || Beaver::Internal::determine_cmd("cxx", "clang++", "g++")
      end
      
      def get_ar
        ENV["AR"] || Beaver::Internal::determine_cmd("ar")
      end
    end
  end
end

