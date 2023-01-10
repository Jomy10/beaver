#!/usr/bin/env ruby
require 'beaver'

$beaver.set(:e) # exit on error

cmd :build, each("src/*.c") do
    sh %(clang #{$file} -c -o src/#{$file.name}.o)
end

cmd :clean do
    $beaver.clean
end

$beaver.end
