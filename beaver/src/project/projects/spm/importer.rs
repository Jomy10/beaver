use std::fs;
use std::path::Path;
use std::sync::Arc;

use log::warn;

use crate::target::LibraryArtifactType;
use crate::traits::AnyTarget;
use crate::{project, target, tools, Beaver, BeaverError};

/// Returns the new project id
pub fn import(
    base_dir: &Path,
    context: &Beaver
) -> crate::Result<usize> {
    let manifest_path = base_dir.join("Package.swift");
    if !manifest_path.exists() {
        return Err(BeaverError::NotASwiftPackagePath(manifest_path));
    }

    let base_dir_str = base_dir.to_string_lossy();

    let build_sys_cache_dir = context.get_build_dir_for_external_build_system_static2(base_dir_str.as_ref())?;
    if !build_sys_cache_dir.exists() {
        fs::create_dir_all(&build_sys_cache_dir)?;
    }
    let cache_dir = build_sys_cache_dir.join("cache");
    let cache_dir = Arc::new(std::path::absolute(cache_dir)?);
    let json_save_path = build_sys_cache_dir.join("manifest.json");

    let file_context = context.optimize_mode.to_string() + ":" + base_dir_str.as_ref();
    let cache = context.cache()?;
    let remake_json = cache.files_changed_in_context(&file_context)? || (!json_save_path.exists());

    let json = if remake_json {
        let output = std::process::Command::new(tools::swift.as_path())
            .args(&["package", "dump-package"])
            .current_dir(base_dir)
            .output()?;

        if !output.status.success() {
            println!("{}", String::from_utf8(output.stderr)?);
            return Err(BeaverError::NonZeroExitStatus(output.status));
        }

        let str = String::from_utf8(output.stdout)?;
        fs::write(json_save_path, &str)?;

        let files = [manifest_path.as_path()];
        context.cache()?.set_all_files(files.into_iter(), &file_context)?;

        str
    } else {
        fs::read_to_string(json_save_path)?
    };

    let manifest = spm_manifest::Manifest::parse(&json)?;

    let targets: Vec<AnyTarget> = manifest.products.into_iter().filter_map(|product| {
        match product.r#type {
            spm_manifest::ProductType::Library(library_type) => {
                let artifact_type = match library_type {
                    spm_manifest::LibraryType::Static => Some(LibraryArtifactType::Staticlib),
                    spm_manifest::LibraryType::Dynamic => Some(LibraryArtifactType::Dynlib),
                    spm_manifest::LibraryType::Automatic => {
                        if remake_json {
                            warn!("SPM Product with automatic library type not imported");
                        }
                        None
                    }
                };

                if let Some(artifact) = artifact_type {
                    Some(AnyTarget::from(target::spm::Library::new(product.name, artifact, cache_dir.clone())))
                } else {
                    None
                }
            },
            spm_manifest::ProductType::Executable => {
                Some(AnyTarget::from(target::spm::Executable::new(product.name, cache_dir.clone())))
            },
            spm_manifest::ProductType::Plugin |
            spm_manifest::ProductType::Snippet |
            spm_manifest::ProductType::Test |
            spm_manifest::ProductType::Macro => {
                if remake_json {
                    warn!("SPM ProductType {:?} is unsupported, will be ignored", product.r#type);
                }

                None
            },
        }
    }).collect();

    if targets.len() == 0 {
        warn!("No products defined in Swift Package Manager project {}", base_dir.display());
    }

    let project = project::spm::Project::new(
        manifest.name,
        std::path::absolute(base_dir)?,
        cache_dir,
        targets,
        context.optimize_mode,
        &context.target_triple
    );

    context.add_project(project)
}
