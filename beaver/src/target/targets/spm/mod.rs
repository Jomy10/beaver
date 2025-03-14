use std::path::{Path, PathBuf};
use std::sync::Arc;

use utils::moduse;

use crate::backend::{rules, BackendBuilderScope, BuildStep};
use crate::target::TArtifactType;
use crate::BeaverError;

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
    objc_header_path: Option<&Path>
) -> crate::Result<String> {
    let Some(package_dir) = project_base_dir.to_str() else {
        return Err(BeaverError::NonUTF8OsStr(project_base_dir.as_os_str().to_os_string()));
    };

    let Some(cache_dir) = cache_dir.to_str() else {
        return Err(BeaverError::NonUTF8OsStr(cache_dir.as_os_str().to_os_string()));
    };

    let step_name = format!("{}$:{}", project_name, target_name);

    // ! rule should be registered in parent project
    scope.add_step(&BuildStep::Cmd {
        rule: &rules::SPM,
        name: &step_name,
        dependencies: &[],
        options: &[
            ("packageDir", package_dir),
            ("product", &target_name),
            ("cacheDir", cache_dir),
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
