use std::ffi::OsString;
use std::path::{Path, PathBuf};
use std::sync::{Arc, RwLock};

use log::warn;
use target_lexicon::Triple;

use crate::backend::{rules, BackendBuilder, BackendBuilderScope, BuildStep, Rule};
use crate::platform::{dynlib_extension_for_os, staticlib_extension_for_os};
use crate::target::parameters::{DefaultArgument, Files, Flags, Headers};
use crate::target::traits::{self, TargetType};
use crate::target::{ArtifactType, Dependency, Language, LibraryArtifactType, Version};
use crate::{Beaver, BeaverError};

use super::TargetDescriptor;

//TODO #[init_descriptor(super::TargetDescriptor, false)]
#[derive(Debug)]
pub struct Library {
    id: Option<usize>,
    project_id: Option<usize>,
    name: String,
    description: Option<String>,
    homepage: Option<url::Url>,
    version: Option<Version>,
    license: Option<String>,

    language: Language,

    sources: Files,

    cflags: Flags,
    headers: Headers,
    linker_flags: Vec<String>,

    artifacts: Vec<LibraryArtifactType>,
    dependencies: Vec<Dependency>,
}

impl Library {
    pub fn new_desc(desc: TargetDescriptor<LibraryArtifactType>) -> Library {
        Library::new(
            desc.name,
            desc.description,
            desc.homepage,
            desc.version,
            desc.license,
            desc.language,
            desc.sources,
            desc.cflags,
            desc.headers,
            desc.linker_flags,
            desc.artifacts,
            desc.dependencies
        )
    }

    pub fn new(
        name: String,
        description: Option<String>,
        homepage: Option<url::Url>,
        version: Option<Version>,
        license: Option<String>,
        language: Language,
        sources: Files,
        cflags: Flags,
        headers: Headers,
        linker_flags: Vec<String>,
        artifacts: DefaultArgument<Vec<LibraryArtifactType>>,
        dependencies: Vec<Dependency>,
    ) -> Library {
        Library {
            id: None,
            project_id: None,
            name,
            description,
            homepage,
            version,
            license,
            language,
            sources,
            cflags,
            headers,
            linker_flags,
            artifacts: artifacts.or_default(vec![
                LibraryArtifactType::Dynlib,
                LibraryArtifactType::Staticlib,
                LibraryArtifactType::PkgConfig,
            ]),
            dependencies
        }
    }
}

impl traits::Target for Library {
    fn name(&self) -> &str {
        &self.name
    }

    fn description(&self) -> Option<&str> {
        self.description.as_ref().map(|s| s.as_str())
    }

    fn homepage(&self) -> Option<&url::Url> {
        self.homepage.as_ref()
    }

    fn version(&self) -> Option<&Version> {
        self.version.as_ref()
    }

    fn license(&self) -> Option<&str> {
        self.license.as_ref().map(|s| s.as_str())
    }

    fn language(&self) -> Language {
        self.language
    }

    fn id(&self) -> Option<usize> {
        self.id
    }

    fn set_id(&mut self, new_id: usize) {
        self.id = Some(new_id);
    }

    fn project_id(&self) -> Option<usize> {
        self.project_id
    }

    fn set_project_id(&mut self, new_id: usize) {
        self.project_id = Some(new_id);
    }

    fn artifacts(&self) -> Vec<crate::target::ArtifactType> {
        self.artifacts.iter().map(|a| ArtifactType::Library(*a)).collect()
    }

    fn dependencies(&self) -> &Vec<crate::target::Dependency> {
        &self.dependencies
    }

    fn r#type(&self) -> TargetType {
        TargetType::Library
    }

    fn default_artifact(&self) -> Option<ArtifactType> {
        if self.artifacts.contains(&LibraryArtifactType::Staticlib) {
            return Some(ArtifactType::Library(LibraryArtifactType::Staticlib));
        } else if self.artifacts.contains(&LibraryArtifactType::Dynlib) {
            return Some(ArtifactType::Library(LibraryArtifactType::Dynlib));
        } else {
            return None;
        }
    }

    fn artifact_output_dir(&self,  project_build_dir: &std::path::Path, target_triple: &Triple) -> std::path::PathBuf {
        _ = target_triple; // todo: support cross-compiling in the future
        project_build_dir.join("artifacts")
    }

    fn artifact_file(&self, project_build_dir: &std::path::Path, artifact: ArtifactType, target_triple: &Triple) -> crate::Result<std::path::PathBuf> {
        let dir = self.artifact_output_dir(project_build_dir, target_triple);
        return match artifact {
            ArtifactType::Library(lib) => match lib {
                LibraryArtifactType::Dynlib => Ok(dir.join(format!("lib{}.{}", self.name, dynlib_extension_for_os(&target_triple.operating_system)?))),
                LibraryArtifactType::Staticlib => Ok(dir.join(format!("lib{}.{}", self.name, staticlib_extension_for_os(&target_triple.operating_system)?))),
                LibraryArtifactType::PkgConfig => Ok(dir.join(format!("{}.pc", self.name))),
                LibraryArtifactType::Framework => {
                    if !target_triple.operating_system.is_like_darwin() {
                        Err(BeaverError::TargetDoesntSupportFrameworks(target_triple.operating_system))
                    } else {
                        Ok(dir.join(format!("{}.framework", self.name)))
                    }
                },
                LibraryArtifactType::XCFramework => {
                    if !target_triple.operating_system.is_like_darwin() {
                        Err(BeaverError::TargetDoesntSupportFrameworks(target_triple.operating_system))
                    } else {
                        Ok(dir.join(format!("{}.xcframework", self.name)))
                    }
                },
            },
            ArtifactType::Executable(_) => panic!("bug")
        };
    }

    fn register<Builder: BackendBuilder<'static>>(&self,
        project_name: &str,
        project_base_dir: &Path,
        project_build_dir: &Path,
        target_triple: &Triple,
        builder: Arc<RwLock<Builder>>,
        context: &Beaver
    ) -> crate::Result<()> {
        let mut guard = builder.write()
            .map_err(|err| BeaverError::BackendLockError(err.to_string()))?;
        for rule in &[&rules::CC as &Rule, &rules::LINK as &Rule] {
            if !guard.has_rule(&rule.name) {
                guard.add_rule(rule);
            }
        }

        // let guard = builder.read()
        //     .map_err(|err| BeaverError::BackendLockError(err.to_string()))?;
        let mut scope = guard.new_scope();
        drop(guard);

        let dependency_steps = self.dependencies.iter()
            .filter_map(|dep| {
                match dep.ninja_name(context) {
                    Err(err) => Some(Err(err)),
                    Ok(val) => match val {
                        Some(val) => Some(Ok(val)),
                        None => None
                    }
                }
            })
            .collect::<crate::Result<Vec<String>>>()?;
        let dependency_steps = dependency_steps.iter()
            .map(|str| str.as_str())
            .collect::<Vec<&str>>();


        let dependencies = self.unique_dependencies_set(context)?;
        let mut artifact_steps: Vec<String> = Vec::new();
        artifact_steps.reserve_exact(self.artifacts.len());
        for artifact in &self.artifacts {
            artifact_steps.push(self.register_artifact(
                artifact,
                project_name, project_base_dir, project_build_dir,
                &target_triple,
                &dependency_steps,
                &self.cflags(project_base_dir, dependencies.iter(), context)?.into_iter().map(|flag| format!("\"{flag}\"")).fold(String::new(), |acc, str| {
                    let mut acc = acc;
                    acc.push_str(&str);
                    acc
                }),
                &self.linker_flags(dependencies.iter(), target_triple, context)?.into_iter().map(|flag| format!("\"{flag}\"")).fold(String::new(), |acc, str| {
                    let mut acc = acc;
                    acc.push_str(&str);
                    acc
                }),
                &mut scope
            )?);
        }

        let target_step = format!("{}$:{}", project_name, self.name);
        scope.add_step(&BuildStep::Phony {
            name: &target_step,
            args: &artifact_steps.iter().map(|str| str.as_str()).collect::<Vec<&str>>(),
            dependencies: &[]
        })?;

        let mut builder_guard = builder.write()
            .map_err(|err| BeaverError::BackendLockError(err.to_string()))?;
        unsafe { builder_guard.apply_scope(scope); }

        return Ok(());
    }
}

impl Library {
    fn register_artifact(&self,
        artifact: &LibraryArtifactType,
        project_name: &str,
        project_base_dir: &Path,
        project_build_dir: &Path,
        target_triple: &Triple,
        dependency_steps: &Vec<&str>,
        cflags: &str,
        linker_flags: &str,
        builder: &mut Box<dyn BackendBuilderScope>
    ) -> crate::Result<String> {
        match artifact {
            LibraryArtifactType::Dynlib | LibraryArtifactType::Staticlib => {
                let obj_ext = OsString::from(if *artifact == LibraryArtifactType::Dynlib { ".dyn.o" } else { ".o" });

                let mut object_files: Vec<PathBuf> = Vec::new();
                let sources = self.sources.resolve(project_base_dir)?;
                if sources.len() == 0 { warn!("No sources in C::Library {}", self.name); }
                for source in sources {
                    let base_source_path = source.as_path().strip_prefix(project_base_dir)
                        .expect("Unexpected error: couldn't strip prefix from source path");
                    let mut object_path = project_build_dir.join(base_source_path);
                    let mut object_filename = object_path.file_name().unwrap().to_os_string();
                    object_filename.push(&obj_ext);
                    object_path.set_file_name(object_filename);

                    object_files.push(object_path);

                    builder.add_step(&BuildStep::Build {
                        rule: &rules::CC,
                        output: &object_files[object_files.len() - 1],
                        input: &vec![source.as_path()],
                        dependencies: &[],
                        options: &[("cflags", cflags)]
                    })?;
                }

                let artifact_file = traits::Target::artifact_file(self, project_build_dir, ArtifactType::Library(*artifact), target_triple)?;
                builder.add_step(&BuildStep::Build {
                    rule: &rules::LINK,
                    output: &artifact_file,
                    input: &object_files.iter().map(|path| path.as_path()).collect::<Vec<&Path>>(),
                    dependencies: &[],
                    options: &[("linkerFlags", linker_flags)]
                })?;

                // TODO: dependencies!
                let artifact_step = format!("{}$:{}$:{}", project_name, &self.name, artifact);
                builder.add_step(&BuildStep::Phony {
                    name: &artifact_step,
                    args: &[&artifact_file.to_str().unwrap()],
                    dependencies: dependency_steps
                })?;

                return Ok(artifact_step);
            },
            LibraryArtifactType::PkgConfig => {
                todo!()
            },
            LibraryArtifactType::Framework => todo!(),
            LibraryArtifactType::XCFramework => todo!()
        }
    }

    // TODO: Cow?

    /// All cflags used by this library when building
    fn cflags<'a>(&self, project_base_dir: &Path, dependencies: impl Iterator<Item = &'a Dependency>, context: &Beaver) -> crate::Result<Vec<String>> {
        let mut cflags: Vec<String> = self.cflags.public.clone();
        cflags.append(&mut self.cflags.private.clone());
        cflags.extend(self.headers.public(project_base_dir).map(|path| format!("-I{}", path.display())));
        cflags.extend(self.headers.private(project_base_dir).map(|path| format!("-I{}", path.display())));

        for dependency in dependencies {
            let Some(mut flags) = dependency.public_cflags(context)? else {
                continue;
            };
            cflags.append(&mut flags);
        }

        cflags.extend(context.optimize_mode.cflags().iter().map(|str| str.to_string()));

        return Ok(cflags);
    }

    /// All linker flags used by this library when linking
    fn linker_flags<'a>(&self, dependencies: impl Iterator<Item = &'a Dependency>, triple: &Triple, context: &Beaver) -> crate::Result<Vec<String>> {
        let mut flags: Vec<String> = self.linker_flags.clone();
        if let Some(additional_linker_flags) = traits::Library::additional_linker_flags(self) {
            flags.extend(additional_linker_flags.iter().map(|str| str.to_owned()));
        }

        for dependency in dependencies {
            let Some(mut depflags) = dependency.linker_flags(triple, context)? else {
                continue;
            };
            flags.append(&mut depflags);
        }

        flags.extend(context.optimize_mode.linker_flags().iter().map(|str| str.to_string()));

        return Ok(flags);
    }
}

impl traits::Library for Library {
    fn public_cflags(&self, project_base_dir: &std::path::Path) -> Vec<String> {
        let mut flags = self.cflags.public.clone();
        for header in self.headers.public(project_base_dir) {
            flags.push(format!("-I{}", header.display()));
        }
        return flags;
    }

    fn additional_linker_flags(&self) -> Option<&Vec<String>> {
        Some(&self.linker_flags)
    }
}
