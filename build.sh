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

for arg in "$args[@]"
do
  echo "> $arg <"

  # Build beaver
  if [[ $arg == "build" ]]; then
    gem build beaver.gemspec
  fi
  
  # Install beaver locally
  if [[ $arg == "install" ]]; then
    gem install beaver-*.gem
  fi

  # Uninstall local gem
  if [[ $arg == "uninstall" ]]; then
    gem uninstall beaver
  fi

  # Clean gem files
  if [[ $arg == "clean" ]]; then
    rm beaver-*.gem
    pushd docs
    mdbook clean
    popd
  fi

  if [[ $arg == "docs" ]]; then
    pushd docs
    mdbook build
    popd
  fi

  # Publish gem to ruby gems
  # if [[ $arg == "publish" ]]; then
  #   gem push beaver-build-*.gem
  # fi

  # Generate the gemspecs
  # if [[ $arg == "gemspec" ]]; then
  #   ruby -e 'gemspec = File.read("template_gemspec"); File.open("beaver.gemspec", "w") {|f| f.write gemspec.gsub("%%%", "beaver")}; File.open("beaver-build.gemspec", "w") {|f| f.write gemspec.gsub("%%%", "beaver-build")}'
  # fi
done
