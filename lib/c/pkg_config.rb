# TODO
module C
  def pkg_config_from_target(target)
    pkg_config_def = {
      Name: target.name,
      Description: target.description,
      URL: target.homepage,
      Version: target.version,
      Requires: target.dependencies,
      # Requires_private: TODO
      Conflicts: target.conflicts,
      Cflags: target._cflags,
      Libs: target._ldflags,
      # Libs_private: TODO
    }.filter do |k, v|
      v != nil
    end
    
    pkg_config_contents = <<-PKG_CONFIG
      prefix=/usr/local
      include_dir=${prefix}/include
      libdir=${prefix}/lib
    PKG_CONFIG
  end
end

