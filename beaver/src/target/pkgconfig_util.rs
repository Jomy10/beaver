use std::path::Path;

use pkgconfig_parser::PkgConfig;
use scoped_env::ScopedEnv;

use super::Dependency;

pub(crate) fn pkgconfig_collect_dependencies(pkg_config: &PkgConfig, base_dir: Option<&Path>) -> crate::Result<Option<Vec<Dependency>>> {
    let current_val = std::env::var("PKG_CONFIG_PATH").unwrap_or("".to_string());
    let new_val = if let Some(dir) = base_dir {
        let abs = std::path::absolute(dir)?;
        let path = abs.to_str().expect("Non UTF-8 path");
        path.to_string() + ":" + current_val.as_str()
    } else {
        current_val
    };
    let _scoped_var = ScopedEnv::set("PKG_CONFIG_PATH", &new_val);

    pkg_config.requires().as_ref().map(|requires| {
        // e.g. Requires: gobject-2.0 >=  2.62, harfbuzz >=  4.3.0
        let deps = requires.split(",");
        let deps: Result<Vec<Dependency>, _> = deps.map(|dep| {
            let mut comps = dep.splitn(1, " ");
            let dep_name = comps.next().unwrap();
            let dep_version_constraint = comps.next();

            Dependency::pkgconfig(dep_name, dep_version_constraint, &[], &[])
        }).collect();
        deps
    }).map_or(Ok(None), |v| v.map(Some)) // Option<Result> to Result<Option>
}
