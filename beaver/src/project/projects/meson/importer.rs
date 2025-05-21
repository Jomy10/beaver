use std::{cmp, fs, io};
use std::path::{Path, PathBuf};
use std::process::Command;

use log::*;

use crate::target::{ExecutableArtifactType, Language, LibraryArtifactType, Version};
use crate::traits::{AnyExecutable, AnyLibrary, AnyTarget, Target};
use crate::{target, tools, Beaver, BeaverError};

// TODO: reconfigure if configure_args changed
pub fn import(
    base_dir: &Path,
    meson_configure_args: &[&str],
    context: &Beaver
) -> crate::Result<usize> {
    let base_dir = std::path::absolute(base_dir)?;
    let base_dir_str = base_dir.to_string_lossy();
    let file_context = context.optimize_mode.to_string() + ":" + base_dir_str.as_ref();

    let (build_dir, reconfigured) = meson_configure(&base_dir, base_dir_str.as_ref(), &file_context, meson_configure_args, context)?;
    let meson_info = build_dir.join("meson-info");

    trace!("Meson importer: storing cache");
    let buildsystem_files_file = fs::File::open(meson_info.join("intro-buildsystem_files.json"))?;
    let buildsystem_files: Vec<String> = serde_json::from_reader(io::BufReader::new(buildsystem_files_file))?;

    context.cache()?.set_all_files(buildsystem_files.iter().map(|path| Path::new(path)), &file_context)?;

    trace!("Meson importer: retrieving targets");

    let project_info_file = fs::File::open(meson_info.join("intro-projectinfo.json"))?;
    let project_info: ProjectInfo = serde_json::from_reader(io::BufReader::new(project_info_file))?;

    let version = Version::parse(&project_info.version);

    let targets_file = fs::File::open(meson_info.join("intro-targets.json"))?;
    let targets_info: Vec<TargetInfo> = serde_json::from_reader(io::BufReader::new(targets_file))?;
    let targets: crate::Result<Vec<AnyTarget>> = targets_info.into_iter()
        .flat_map(|target_info| {
            let language = target_info.target_sources.iter()
                .find_map(|source| match source {
                    TargetSource::Source(source) => Some(&source.language),
                    _ => None
                }).map(|language| if language == "unknown" { Language::C } else { Language::parse(&language.as_str()).expect(&format!("Invalid language '{}'", language)) })
                .unwrap_or(Language::C);
            match target_info.ty.as_str() {
                "executable" => {
                    trace!("Meson importer: importing executable {}", target_info.name);

                    let artifact = PathBuf::from(target_info.filename.first().expect(&format!("No artifacts found for {}", &target_info.name)));
                    let target = target::meson::Executable::new(
                        target_info.id,
                        target_info.name,
                        version.clone(),
                        language,
                        ExecutableArtifactType::Executable,
                        artifact
                    );
                    Some(Ok(AnyTarget::Executable(AnyExecutable::Meson(target))))
                },
                "static library" | "shared library" => {
                    trace!("Meson importer: importing library {}", target_info.name);
                    // let linker_flags: Option<Vec<String>> = target_info.target_sources.iter()
                    //     .find_map(|source| match source {
                    //         TargetSource::Linker(target_source_linker) => Some(target_source_linker.parameters.clone()),
                    //         _ => None
                    //     });
                    let artifact = PathBuf::from(target_info.filename.first().expect(&format!("No artifacts found for {}", &target_info.name)));
                    let target = target::meson::Library::new(
                        target_info.id,
                        target_info.name,
                        version.clone(),
                        language,
                        if target_info.ty.as_str() == "static library" { LibraryArtifactType::Staticlib } else { LibraryArtifactType::Dynlib },
                        artifact,
                        &build_dir
                    );
                    Some(target.map(|target| AnyTarget::Library(AnyLibrary::Meson(target))))
                },
                _ => {
                    if reconfigured {
                        warn!("Unsupported meson target type {}", target_info.ty);
                    }
                    None
                }
            }
        }).collect();
    let mut targets = targets?;
    let mut to_remove = Vec::new();
    for (i1, t1) in targets.iter().enumerate() {
        for (i2, t2) in targets.iter().enumerate() {
            if i1 == i2 { continue }

            if t1.name() == t2.name() {
                to_remove.push(cmp::max(i1, i2))
            }
        }
    }
    for i in to_remove.iter().rev() {
        let target = targets.remove(*i);
        warn!("Didn't import target {} ({:?}) because it is already defined.", target.name(), target.artifacts().first().unwrap());
    }

    trace!("Meson importer: setting up project");

    let project = super::Project::new(
        project_info.descriptive_name,
        base_dir,
        build_dir,
        targets
    );

    context.add_project(project)?;

    Ok(context.current_project_index().unwrap())
}

// TODO: if fails, remove cache
fn meson_configure(
    base_dir: &Path,
    base_dir_str: &str,
    file_context: &str,
    meson_configure_args: &[&str],
    context: &Beaver
) -> crate::Result<(PathBuf, bool)> {
    let build_dir = context.get_build_dir_for_external_build_system2(base_dir_str)?;

    let cache = context.cache()?;
    let meson_build_files_changed = cache.files_changed_in_context(&file_context)?;
    let reconfigure = !build_dir.exists() || meson_build_files_changed;

    if reconfigure {
        trace!("Reconfiguring Meson project {}", base_dir_str);

        let build_dir = build_dir.to_str().expect("Non-UTF8 file path");

        let color_arg = format!("-Db_colorout={}", if context.color_enabled() { "always" } else { "never" }); // TODO: cache this option
        let mut args = vec![
            "setup",
            "--reconfigure",
            &color_arg,
            &build_dir
        ];
        args.extend_from_slice(meson_configure_args);

        let console_style = console::Style::new().fg(console::Color::Color256(8));
        eprintln!("{}", console_style.apply_to(format!("meson {}", &args.join(" "))));

        let mut process = Command::new(&*tools::meson)
            .args(&args)
            .current_dir(&base_dir)
            .spawn()?;

        let status = process.wait()?;
        if !status.success() {
            return Err(BeaverError::MesonFailed);
        }
    }

    Ok((build_dir, reconfigure))
}

#[derive(serde::Deserialize)]
struct ProjectInfo {
    version: String,
    descriptive_name: String,
    // currently unused:
    // license: Vec<String>,
    // license_files: Vec<String>,
    // subproject_dir: String,
    // subprojects: Vec<String>,
}

#[derive(serde::Deserialize, Debug)]
struct TargetInfo {
    name: String,
    id: String,
    #[serde(rename = "type")]
    ty: String,
    #[allow(unused)]
    defined_in: String,
    filename: Vec<String>,
    #[allow(unused)]
    build_by_default: bool,
    target_sources: Vec<TargetSource>
}

#[derive(serde::Deserialize, Debug)]
#[serde(untagged)]
enum TargetSource {
    Source(TargetSourceSource),
    #[allow(unused)]
    Linker(TargetSourceLinker),
    #[allow(unused)]
    Any(serde_json::Value)
}

// I didn't know what to name this
#[derive(serde::Deserialize, Debug)]
struct TargetSourceSource {
    language: String,
    // ...
}

#[derive(serde::Deserialize, Debug)]
#[allow(unused)]
struct TargetSourceLinker {
    linker: String,
    parameters: Vec<String>,
}
