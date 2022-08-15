#!/usr/bin/env zsh

for arg in "$@"
do
  if [[ $arg == "build" ]]; then
    gem build beaver.gemspec
  fi

  if [[ $arg == "install" ]]; then
    gem install beaver-*.gem
  fi

  if [[ $arg == "clean" ]]; then
    gem uninstall beaver
    rm beaver-*.gem
  fi
done
