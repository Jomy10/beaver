use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;

use cmake_file_api::objects::{codemodel_v2, CMakeFilesV1, CodeModelV2};
use itertools::Itertools;
use log::{trace, warn};

use crate::project::projects;
use crate::target::cmake;
use crate::target::{Dependency, ExecutableArtifactType, Language, LibraryArtifactType};
use crate::traits::{AnyExecutable, AnyLibrary, AnyTarget};
use crate::{tools, Beaver, BeaverError};

// TODO: debug why cmake keeps re-configuring
pub fn import(
    base_dir: &Path,
    cmake_flags: &[&str],
    context: &Beaver
) -> crate::Result<()> {
    let base_dir = std::path::absolute(base_dir)?;

    let base_dir_str = base_dir.to_string_lossy();
    let file_context = context.optimize_mode.cmake_name().to_string() + ":" + base_dir_str.as_ref();

    let build_dir = context.get_build_dir_for_external_build_system2(base_dir_str.as_ref())?;

    let build_dir_exists = build_dir.exists();
    if !build_dir_exists {
        fs::create_dir_all(&build_dir)?;
    }

    // Make requests
    let api_dir = build_dir.join(".cmake/api/v1");
    let reply_dir = api_dir.join("reply");
    let query_dir = api_dir.join("query");

    let query_dir_exists = query_dir.exists();
    if !query_dir_exists {
        fs::create_dir_all(&query_dir)?;
    }

    let codemodel_req = query_dir.join("codemodel-v2");
    if !codemodel_req.exists() {
        fs::File::create(codemodel_req)?;
    }

    let cmake_files_req = query_dir.join("cmakeFiles-v1");
    if !cmake_files_req.exists() {
        fs::File::create(cmake_files_req)?;
    }

    // Execute cmake
    let cache = context.cache()?;
    let cmake_files_changed = cache.files_changed_in_context(&file_context)?;
    let reconfigure = cmake_files_changed || !build_dir_exists || !query_dir_exists || !reply_dir.exists();
    if reconfigure {
        trace!("Reconfiguring CMake project {:?}", base_dir);

        let build_type_arg = format!("-DCMAKE_BUILD_TYPE={}", context.optimize_mode.cmake_name());
        let mut args = vec![
            base_dir_str.as_ref(),
            &build_type_arg,
            "-G", "Ninja"
        ];
        args.extend_from_slice(cmake_flags);

        let mut process = Command::new(&*tools::cmake)
            .args(&args)
            .current_dir(&build_dir)
            .spawn()?;

        let status = process.wait()?;
        if !status.success() {
            return Err(BeaverError::CMakeFailed);
        }
    }

    trace!("CMake importer: reading queries");

    // Read query replies
    let reader = cmake_file_api::reply::Reader::from_build_dir(&build_dir)?;

    // Store CMake files to determine if reconfiguring is needed later
    if reconfigure {
        trace!("CMake importer: storing cache");
        let cmake_files: CMakeFilesV1 = reader.read_object()?;
        let inputs = cmake_files.inputs.into_iter()
            .map(|input| base_dir.join(input.path))
            .unique()
            .collect::<Vec<PathBuf>>();
        context.cache()?.set_all_files(inputs.iter().map(|pathbuf| pathbuf.as_path()), &file_context)?;
    }

    trace!("CMake importer: reading codemodel");

    let codemodel: CodeModelV2 = reader.read_object()?;
    let Some(cmake_config) = codemodel.configurations.iter().find(|config| {
        config.name == context.optimize_mode.cmake_name()
    }) else {
        return Err(BeaverError::CMakeMissingConfig(context.optimize_mode.cmake_name()));
    };

    trace!("CMake importer: reading replies to targets and projects");

    for project in cmake_config.projects.iter() {
        let mut targets: Vec<AnyTarget> = Vec::new();

        for target_index in project.target_indexes.iter() {
            let target = &cmake_config.targets[*target_index];

            match target.type_name.as_str() {
                "STATIC_LIBRARY" => {
                    add_library(target, LibraryArtifactType::Staticlib, &mut targets, &build_dir)?;
                },
                "SHARED_LIBRARY" => {
                    add_library(target, LibraryArtifactType::Dynlib, &mut targets, &build_dir)?;
                },
                "EXECUTABLE" => {
                    add_executable(target, &mut targets, &build_dir)?;
                },
                name => {
                    if reconfigure {
                        warn!("CMake target type '{}' will not be mapped to a target (currently unsupported)", name)
                    }
                    continue
                }
            }
        }

        trace!("CMake importer: adding project {}", &project.name);

        let project = projects::cmake::Project::new(
            project.name.clone(),
            base_dir.to_path_buf(),
            build_dir.clone(),
            targets
        );
        context.add_project(project)?;
    }

    Ok(())
}

fn add_library(target: &codemodel_v2::Target, artifact_type: LibraryArtifactType, targets: &mut Vec<AnyTarget>, build_dir: &Path) -> crate::Result<()> {
    if target.artifacts.len() != 1 {
        if target.artifacts.len() == 0 {
            warn!("{} is not supported because it has no artifacts", target.name);
        } else {
            warn!("{} is not imported because it has multiple artifacts. Please open an issue on GitHub (artifacts are: {:?})", target.name, target.artifacts);
        }
    }

    let artifact_path = build_dir.join(&target.artifacts[0].path);

    if target.compile_groups.len() > 1 {
        warn!("Multiple compile groups found for {}", target.name);
    }

    let mut language: Option<&str> = None;
    let cflags = target.compile_groups.iter().fold(Vec::new(), |acc, compile_group| {
        let mut acc = acc;
        acc.extend(
            compile_group.defines().iter().map(|define| format!("-D{}", define))
                .chain(compile_group.includes.iter().map(|include| format!("-I{}", include.path.display())))
        );
        // TODO: min language standard
        // if let Some(stand) = compile_group.language_standard {
        //     acc.push(format!("-std={}", stand.standard));
        // }
        match language {
            None => language = Some(&compile_group.language),
            Some(lang) => if lang != compile_group.language {
                warn!("CMake target contains multiple languages {} and {}", lang, compile_group.language);
            }
        }
        acc
    });

    let language = language.map(|lang| match Language::parse(lang) {
        Some(lang) => Ok(lang),
        None => Err(BeaverError::CMakeUnknownLanguage(lang.to_string()))
    }).unwrap_or(Ok(Language::C))?;

    // TODO
    let linker_flags = vec![];

    let dependencies = target.dependencies.iter().map(|dep| {
        Dependency::CMakeId(dep.id.clone())
    }).collect();

    targets.push(
        AnyTarget::Library(AnyLibrary::CMake(
            cmake::Library::new(
                target.id.clone(),
                target.name.clone(),
                language,
                artifact_type,
                artifact_path.clone(),
                cflags,
                linker_flags,
                dependencies
            )
        ))
    );

    Ok(())
}

fn add_executable(target: &codemodel_v2::Target, targets: &mut Vec<AnyTarget>, build_dir: &Path) -> crate::Result<()> {
    if target.artifacts.len() != 1 {
        if target.artifacts.len() == 0 {
            warn!("{} is not supported because it has not artifacts", target.name);
        } else {
            warn!("{} is not imported because it has multiple artifacts. Please open an issue on GitHub (artifacts are: {:?})", target.name, target.artifacts);
        }
    }

    let artifact_path = build_dir.join(&target.paths.build).join(&target.artifacts[0].path);

    let language = target.compile_groups.first().map(|g| &g.language);
    let language = if let Some(language) = language {
        let Some(language) = Language::parse(&language) else {
            return Err(BeaverError::CMakeUnknownLanguage(language.clone()));
        };
        language
    } else {
        Language::C
    };

    targets.push(AnyTarget::Executable(AnyExecutable::CMake(
        cmake::Executable::new(
            target.id.clone(),
            target.name.clone(),
            language,
            ExecutableArtifactType::Executable,
            artifact_path.clone()
        )
    )));

    Ok(())
}
