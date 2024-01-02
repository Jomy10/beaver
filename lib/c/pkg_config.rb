module C
  def self.pkg_config_from_target(target)
    pkg_config_def = {
      Name: target.name,
      Description: target.description,
      URL: target.homepage,
      Version: target.version,
      Requires: target.dependencies.map { |d|
        target.project.get_target(d.name)
      }.filter { |d|
        d.library_type == LibraryType::PKG_CONFIG
      }.map { |d|
        "#{d.name} #{d.version}"
      }.join(" "),
      # Requires_private: TODO
      Conflicts: target.conflicts,
      Cflags: target.public_cflags.join(" "),#.push(*target.private_cflags).join(" "),
      Libs: target._ldflags,
      # Libs_private: TODO
    }.filter do |k, v|
      v != nil
    end
    
    pkg_config_str = pkg_config_def.map { |c, v| "#{c.to_s.gsub("_", ".")}: #{v}"}.join("\n")
    
    pkg_config_contents = <<-PKG_CONFIG
prefix=/usr/local
include_dir=${prefix}/include
libdir=${prefix}/lib

#{pkg_config_str}
    PKG_CONFIG
    
    return pkg_config_contents
  end
end

