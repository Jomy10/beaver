#!/usr/bin/env zsh

# NOTE: if you are using bash, change zsh above to bash,
# or run this script using `bash build.sh`

args=( "$@" )

for arg in $args
do
  # Uninstall beaver and remove gem files
  if [[ $arg == "clean-all" ]]; then
    args+=( "clean" )
    args+=( "uninstall" )
  fi
done

for arg in $args
do
  # Build beaver
  if [[ $arg == "build" ]]; then
    gem build beaver.gemspec
  fi
  
  # Build beaver-build
  if [[ $arg == "build-gem" ]]; then
    gem build beaver-build.gemspec
  fi

  # Install beaver locally
  if [[ $arg == "install" ]]; then
    gem install beaver-*.gem
  fi

  # Uninstall local gem
  if [[ $arg == "uninstall" ]]; then
    echo "uninstalling"
    gem uninstall beaver
  fi

  # Clean gem files
  if [[ $arg == "clean" ]]; then
    echo "cleaning"
    rm beaver-*.gem
    rm beaver-build-*.gem
  fi

  # Publish gem to ruby gems
  if [[ $arg == "publish" ]]; then
    gem push beaver-build-*.gem
  fi
done
