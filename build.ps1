for ($i = 0; $i -lt $args.count; $i++) {
  $arg = $args[$i]

  if ($arg -eq "build") {
    gem build beaver.gemspec
  }

  if ($arg -eq "install") {
    gem install beaver-*.gem
  }

  if ($arg -eq "uninstall") {
    gem uninstall beaver
  }

  if ($arg -eq "clean") {
    Get-ChildItem -Path "." | Where{$_.Name -match "beaver.*\.gem"} | Remove-Item
  }

  if ($arg -eq "test") {
    ruby tests/test.rb -v
  }
}
