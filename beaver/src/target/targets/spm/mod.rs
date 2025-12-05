use std::path::{Path, PathBuf};
use std::sync::Arc;

use target_lexicon::Triple;
use utils::moduse;

use crate::backend::{rules, BackendBuilderScope, BuildStep};
use crate::target::{Dependency, TArtifactType};
use crate::{Beaver, BeaverError};

moduse!(library);
moduse!(executable);

fn register_target<ArtifactType: TArtifactType>(
    scope: &mut impl BackendBuilderScope,
    project_name: &str,
    target_name: &str,
    project_base_dir: &Path,
    artifact_file: &Path,
    artifact: ArtifactType,
    cache_dir: &Arc<PathBuf>,
    objc_header_path: Option<&Path>,
    extra_dependencies: &Vec<Dependency>,
    ctx: &Beaver,
    triple: &Triple
) -> crate::Result<String> {
    let Some(package_dir) = project_base_dir.to_str() else {
        return Err(BeaverError::NonUTF8OsStr(project_base_dir.as_os_str().to_os_string()));
    };

    let Some(cache_dir) = cache_dir.to_str() else {
        return Err(BeaverError::NonUTF8OsStr(cache_dir.as_os_str().to_os_string()));
    };

    let step_name = format!("{}$:{}", project_name, target_name);

    let mut extra_flags: Vec<String> = Vec::new();
    for dep in extra_dependencies {
        let mut linker_flags = Vec::new();
        let mut extra_files = Vec::new();
        dep.linker_flags(triple, ctx, &mut linker_flags, &mut extra_files)?;

        extra_flags.push("-Xlinker".to_string());
        extra_flags.extend(linker_flags.into_iter()
            .intersperse("-Xlinker".to_string()));

        let mut cflags = Vec::new();
        dep.public_cflags(ctx, &mut cflags, &mut extra_files)?;

        extra_flags.push("-Xcc".to_string());
        extra_flags.extend(cflags.into_iter()
            .intersperse("-Xcc".to_string()));

        if extra_files.len() > 0 {
            eprintln!("[UNIMPLEMENTED] extra_files in SwiftPM target (dependency) {:?}", extra_files)
        }
    }

    log::debug!("Extra flags for SPM target {}: {:?}", target_name, extra_flags);

    // ! rule should be registered in parent project
    scope.add_step(&BuildStep::Cmd {
        rule: &rules::SPM,
        name: &step_name,
        dependencies: &[],
        options: &[
            ("packageDir", package_dir),
            ("product", &target_name),
            ("cacheDir", cache_dir),
            ("extra_flags", &extra_flags.join(" ")),
        ],
    })?;

    // define how to build the objc header.
    // This headers is included in dependants
    if let Some(objc_header) = objc_header_path {
        let Some(objc_header) = objc_header.to_str() else {
            return Err(BeaverError::NonUTF8OsStr(objc_header.as_os_str().to_os_string()));
        };

        scope.add_step(&BuildStep::Phony {
            name: objc_header,
            args: &[&step_name],
            dependencies: &[],
        })?;
    }

    let Some(artifact_file) = artifact_file.to_str() else {
        return Err(BeaverError::NonUTF8OsStr(artifact_file.as_os_str().to_os_string()));
    };

    scope.add_step(&BuildStep::Phony {
        name: artifact_file,
        args: &[&step_name],
        dependencies: &[],
    })?;

    scope.add_step(&BuildStep::Phony {
        name: &format!("{}$:{}", step_name, artifact),
        args: &[artifact_file],
        dependencies: &[],
    })?;

    Ok(step_name)
}
