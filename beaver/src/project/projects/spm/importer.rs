use std::fs;
use std::path::Path;

use log::{debug, warn};

use crate::target::LibraryArtifactType;
use crate::traits::AnyTarget;
use crate::{project, target, tools, Beaver, BeaverError};

pub fn import(
    base_dir: &Path,
    context: &Beaver
) -> crate::Result<()> {
    let manifest_path = base_dir.join("Package.swift");

    let Some(base_dir_str) = base_dir.as_os_str().to_str() else {
        return Err(BeaverError::NonUTF8OsStr(base_dir.as_os_str().to_os_string()));
    };

    let json_save_path = context.get_build_dir()?.join("__external").join("swift-package-manager-manifests").join(urlencoding::encode(base_dir_str));
    let file_context = context.optimize_mode.to_string() + ":" + base_dir_str;
    let remake_json = context.cache()?.files_changed_in_context(&file_context)? || (!json_save_path.exists());

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
        context.cache()?.add_all_files(files.iter(), &file_context)?;

        str
    } else {
        fs::read_to_string(json_save_path)?
    };

    let manifest = spm_manifest::Manifest::parse(&json)?;

    let targets: Vec<AnyTarget> = manifest.products.into_iter().filter_map(|product| {
        match product.r#type {
            spm_manifest::ProductType::Library(library_type) => {
                Some(AnyTarget::from(target::spm::Library::new(product.name, match library_type {
                    spm_manifest::LibraryType::Static => LibraryArtifactType::Staticlib,
                    spm_manifest::LibraryType::Dynamic => LibraryArtifactType::Dynlib,
                    spm_manifest::LibraryType::Automatic => {
                        if remake_json {
                            debug!("LibraryType::Automatic found for SPM product; assuming staticlib")
                        }
                        LibraryArtifactType::Staticlib
                    },
                })))
            },
            spm_manifest::ProductType::Executable => {
                Some(AnyTarget::from(target::spm::Executable::new(product.name)))
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

    let project = project::spm::Project::new(manifest.name, base_dir.to_path_buf(), context.get_build_dir()?, targets);

    context.add_project(project);

    return Ok(());
}
