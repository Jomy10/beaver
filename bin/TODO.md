# Executable

when $1 == "init"
	-> Initialize project
else
	run beaver file ./make.rb $@

- Global config file -> ~/.config/beaver.toml

