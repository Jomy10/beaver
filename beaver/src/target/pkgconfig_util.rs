use pkgconfig_parser::PkgConfig;

use super::Dependency;

pub(crate) fn pkgconfig_collect_dependencies(pkg_config: &PkgConfig) -> crate::Result<Option<Vec<Dependency>>> {
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
