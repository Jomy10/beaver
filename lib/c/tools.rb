module Beaver
  module C
    module Internal
      def self.get_cc
        # https://cmake.org/pipermail/cmake/2013-March/053819.html
        ENV["CC"] || Beaver::Internal::determine_cmd("cc", "clang", "gcc", "cl", "bcc", "xlc")
      end
      
      def self.get_cxx
        ENV["CXX"] || Beaver::Internal::determine_cmd("cxx", "c++", "clang++", "g++")
      end
      
      def self.get_ar
        ENV["AR"] || Beaver::Internal::determine_cmd("ar")
      end
      
      def self.get_objc_compiler
        ENV["OBJC_COMPILER"] || (
          if `uname`.include?("Darwin")
            "clang"
          else
            "gcc" #{`gnustep-config --objc-flags`.gsub("\n", "")}"
          end
        )
      end
    end
  end
end

