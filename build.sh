#!/usr/bin/env zsh

for arg in "$@"
do
  if [[ $arg == "build" ]]; then
    gem build beaver.gemspec
  fi
  
  if [[ $arg == "build-gem" ]]; then
    gem build beaver-build.gemspec
  fi

  if [[ $arg == "install" ]]; then
    gem install beaver-*.gem
  fi

  if [[ $arg == "clean" ]]; then
    gem uninstall beaver
    rm beaver-*.gem
  fi
  
  if [[ $arg == "publish" ]]; then
    gem push beaver-build-*.gem
  fi
done
