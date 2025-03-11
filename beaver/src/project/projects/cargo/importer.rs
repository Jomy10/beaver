use std::path::Path;
use std::sync::Arc;
use cargo_manifest::{Manifest, Workspace};
use log::warn;
use url::Url;

use crate::target::{ExecutableArtifactType, LibraryArtifactType};
use crate::traits::{AnyExecutable, AnyLibrary, AnyTarget};
use crate::{target, Beaver, BeaverError};
use super::Project as CargoProject;

pub fn import(
    base_dir: &Path,
    cargo_flags: Vec<String>, // TODO
    context: &Beaver
) -> crate::Result<()> {
    let cargo_args = Arc::new(cargo_flags);

    let manifest_path = base_dir.join("Cargo.toml");
    let manifest = Manifest::from_path_with_metadata(&manifest_path)?;

    let mut targets: Vec<AnyTarget> = Vec::new();

    let project_name: String;
    if let Some(workspace) = &manifest.workspace {
        project_name = base_dir.components().last()
            .map(|comp| comp.as_os_str().to_str().expect("invalid unicode").to_string())
            .unwrap_or(format!("Cargo project {}", uuid::Uuid::new_v4()));

        if manifest.package.is_some() { // top-level package
            let (mut exes, lib) = parse_package(&manifest, Some(workspace), cargo_args.clone())?;
            if let Some(lib) = lib {
                targets.push(lib);
            }
            targets.append(&mut exes);
        }

        // Can easily be parallelized
        for member in &workspace.members {
            let member_cargo_manifest = base_dir.join(member).join("Cargo.toml");
            let manifest = Manifest::from_path_with_metadata(member_cargo_manifest)?;
            let (mut exes, lib) = parse_package(&manifest, Some(&workspace), cargo_args.clone())?;
            if let Some(lib) = lib {
                targets.push(lib);
            }
            targets.append(&mut exes);
        }
    } else if manifest.package.is_some() {
        project_name = manifest.package.as_ref().unwrap().name.clone();

        let (mut exes, lib) = parse_package(&manifest, None, cargo_args.clone())?;
        if let Some(lib) = lib {
            targets.push(lib);
        }
        targets.append(&mut exes);
    } else {
        panic!("No targets in Cargo project"); // TODO: error
    }

    context.add_project(CargoProject::new(
        project_name,
        cargo_args,
        base_dir.to_path_buf(),
        targets
    ))?;

    Ok(())
}

fn parse_package(manifest: &Manifest, workspace: Option<&Workspace>, cargo_args: Arc<Vec<String>>) -> crate::Result<(Vec<AnyTarget>, Option<AnyTarget>)> {
    let workspace_package = workspace.and_then(|workspace| workspace.package.clone());
    let package = manifest.package.as_ref().expect("Always present if it's not a workspace");
    let name = &package.name;
    let version = package.version().as_local().or(workspace_package.as_ref().and_then(|package| package.version.as_deref()));
    let version = version.map(|version| crate::target::Version::parse(version));
    let description = package.description.as_ref().and_then(|description| {
        description.as_ref().as_local().or(workspace_package.as_ref().and_then(|package| package.description.as_ref()))
    });
    let homepage = package.homepage.as_ref().and_then(|homepage| homepage.as_ref().as_local().or(workspace_package.as_ref().and_then(|package| package.homepage.as_ref())));
    let homepage = if let Some(homepage) = homepage {
        match Url::parse(&homepage) {
            Ok(homepage) => Some(homepage),
            Err(err) => {
                warn!("Couldn't parse Cargo homepage url {:?}", err);
                None
            },
        }
    } else {
        None
    };
    let license = package.license.as_ref().and_then(|license| license.as_ref().as_local().or(workspace_package.as_ref().and_then(|package| package.license.as_ref())));

    let bins: Vec<AnyTarget> = manifest.bin.iter().filter_map(|bin| 'bin: {
        let Some(bin_name) = &bin.name else {
            warn!("Couldn't determine name for an executable of cargo package {} (skipping)", &name);
            break 'bin None;
        };
        Some(Ok(
            AnyTarget::Executable(
                AnyExecutable::Cargo(
                    target::cargo::Executable::new(
                        bin_name.clone(),
                        description.map(|str| str.clone()),
                        homepage.clone(),
                        version.clone(),
                        license.map(|str| str.to_string()),
                        vec![ExecutableArtifactType::Executable],
                        cargo_args.clone()
                    )
                )
            )
        ))
    }).collect::<crate::Result<Vec<AnyTarget>>>()?;

    let library: Option<target::cargo::Library> = 'lib: {
        // TODO: features -> allow picking features from dependency class
        if let Some(lib) = &manifest.lib {
            let Some(lib_name) = &lib.name else {
                warn!("Couldn't determine name for library of cargo package {} (skipping)", &name);
                break 'lib None;
            };
            let Some(crate_types) = &lib.crate_type else {
                warn!("Couldn't determine crate-type for {} (skipping)", lib_name);
                break 'lib None;
            };
            let artifacts = crate_types.into_iter().map(|crate_type| {
                match crate_type.as_str() {
                    "rlib" => Ok(LibraryArtifactType::RustLib),
                    "dylib" => Ok(LibraryArtifactType::RustDynlib),
                    "staticlib" => Ok(LibraryArtifactType::Staticlib),
                    "cdylib" => Ok(LibraryArtifactType::Dynlib),
                    _ => Err(BeaverError::InvalidLibraryArtifactType(crate_type.clone()))
                }
            }).collect::<Result<Vec<LibraryArtifactType>, BeaverError>>()?;

            Some(target::cargo::Library::new(
                lib_name.clone(),
                description.map(|str| str.clone()),
                homepage,
                version,
                license.map(|str| str.to_string()),
                artifacts,
                cargo_args.clone()
            ))
        } else {
            None
        }
    };

    Ok((bins, library.map(|library| AnyTarget::Library(AnyLibrary::Cargo(library)))))
}
