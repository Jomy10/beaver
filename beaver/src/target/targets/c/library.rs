use std::borrow::Cow;
use std::collections::HashSet;
use std::ffi::OsString;
use std::path::{Path, PathBuf};
use std::sync::{Arc, RwLock};

use log::{trace, warn};
use target_lexicon::{OperatingSystem, Triple};

use crate::backend::{rules, BackendBuilder, BackendBuilderScope, BuildStep};
use crate::platform::{dynlib_extension_for_os, dynlib_linker_flags_for_os, staticlib_extension_for_os};
use crate::target::parameters::{DefaultArgument, Files, Flags, Headers};
use crate::target::traits::{self, TargetType};
use crate::target::{self, ArtifactType, Dependency, Language, LibraryArtifactType, Version};
use crate::traits::Library as _;
use crate::{Beaver, BeaverError};

use super::{CTarget, Setting, TargetDescriptor};

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

    settings: Vec<crate::target::c::Setting>,
}

impl Library {
    pub fn new_desc(desc: TargetDescriptor<LibraryArtifactType>) -> crate::Result<Library> {
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
            desc.dependencies,
            desc.settings
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
        settings: Vec<Setting>
    ) -> crate::Result<Library> {
        target::utils::check_language(&[Language::C, Language::CXX, Language::OBJC, Language::OBJCXX], &language, "C")?;

        let artifacts = artifacts.or_default(vec![
            LibraryArtifactType::Dynlib,
            LibraryArtifactType::Staticlib,
            // LibraryArtifactType::PkgConfig,
        ]);
        let valid_artifacts = HashSet::from([LibraryArtifactType::Dynlib, LibraryArtifactType::Staticlib, LibraryArtifactType::Framework, LibraryArtifactType::XCFramework, LibraryArtifactType::PkgConfig, LibraryArtifactType::JSLib]);
        target::utils::check_artifacts(&valid_artifacts, &artifacts, "C")?;

        Ok(Library {
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
            artifacts,
            dependencies,
            settings
        })
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

    fn dependencies(&self) -> crate::Result<Cow<'_, [Dependency]>> {
        Ok(Cow::Borrowed(&self.dependencies))
    }

    fn r#type(&self) -> TargetType {
        TargetType::Library
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
                LibraryArtifactType::JSLib => {
                    if target_triple.operating_system != OperatingSystem::Emscripten {
                        Err(BeaverError::TargetDoesntSupportJSLib(target_triple.operating_system))
                    } else {
                        Ok(dir.join(format!("{}.js", self.name)))
                    }
                }
                _ => unreachable!("Unsupported artifact for C") // TODO: validate in `new`
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
        scope: &mut Builder::Scope,
        context: &Arc<Beaver>
    ) -> crate::Result<String> {
        let mut rules = Vec::from([self.cc_rule(), self.link_rule(), &rules::AR]);
        if target_triple.operating_system == OperatingSystem::Emscripten && self.artifacts.contains(&LibraryArtifactType::JSLib) {
            rules.push(self.jslib_rule()?)
        }

        CTarget::register_impl(
            self,
            project_name,
            project_base_dir,
            project_build_dir,
            target_triple,
            builder,
            scope,
            &rules,
            context
        )
    }

    fn debug_attributes(&self) -> Vec<(&'static str, String)> {
        vec![
            ("sources", format!("{:?}", self.sources.resolve())),
            ("cflags", format!("{:?}", self.cflags)),
            ("headers", format!("{:?}", self.headers)),
            ("linker_flags", self.linker_flags.join(", ")),
        ]
    }
}

impl CTarget for Library {
    type TargetArtifactType = LibraryArtifactType;

    fn user_cflags(&self) -> impl Iterator<Item = &String> {
        self.cflags.public.iter()
            .chain(self.cflags.private.iter())
    }

    fn all_headers<'a>(&'a self, project_base_dir: &'a Path) -> impl Iterator<Item = PathBuf> + 'a {
        self.headers.public(project_base_dir)
            .chain(self.headers.private(project_base_dir))
    }

    fn target_artifacts(&self) -> &[Self::TargetArtifactType] {
        &self.artifacts
    }

    fn settings(&self) -> &[Setting] {
        &self.settings
    }

    /// All linker flags used by this library when linking
    fn linker_flags<'a>(&self, dependencies: impl Iterator<Item = &'a Dependency>, languages: impl Iterator<Item = &'a Language>, triple: &Triple, context: &Beaver) -> crate::Result<(Vec<String>, Vec<PathBuf>)> {
        let mut flags: Vec<String> = dynlib_linker_flags_for_os(&triple.operating_system)?.iter().map(|s| s.to_string()).collect();

        flags.append(&mut self.linker_flags.clone());

        let mut additional_files = Vec::new();
        for dependency in dependencies {
            dependency.linker_flags(triple, context, &mut flags, &mut additional_files)?;
        }
        for lang in languages {
            let Some(lang_flags) = Language::linker_flags(*lang, self.language, triple) else { continue };
            flags.extend(lang_flags.iter().map(|str| str.to_string()))
        }

        flags.extend(context.optimize_mode.linker_flags().iter().map(|str| str.to_string()));

        if (self.language == Language::OBJC || self.language == Language::OBJCXX) && self.settings.contains(&Setting::ObjCArc) {
            flags.push("-fobjc-arc".to_string());
        }

        return Ok((flags, additional_files));
    }

    fn register_artifact<Scope: BackendBuilderScope>(&self,
        artifact: &LibraryArtifactType,
        project_name: &str,
        project_base_dir: &Path,
        project_build_dir: &Path,
        target_triple: &Triple,
        dependency_steps: &[&str],
        cflags: &str,
        linker_flags: &str,
        additional_artifact_files: &[PathBuf],
        additional_dependency_files: &[&str],
        builder: &mut Scope
    ) -> crate::Result<String> {
        let cc_rule = self.cc_rule();
        let link_rule = self.link_rule();

        let object_file_path = project_build_dir.join("objects");
        match artifact {
            LibraryArtifactType::Dynlib | LibraryArtifactType::Staticlib | LibraryArtifactType::JSLib => {
                let obj_ext = OsString::from(if *artifact == LibraryArtifactType::Dynlib { ".dyn.o" } else { ".o" });

                let mut object_files: Vec<PathBuf> = Vec::new(); //additional_artifact_files.to_vec();
                let sources = self.sources.resolve()?;
                if sources.len() == 0 { warn!("No sources in C::Library {}", self.name); }
                for source in sources {
                    let base_source_path = source.as_path().strip_prefix(project_base_dir)
                        .expect("Unexpected error: couldn't strip prefix from source path");
                    let mut object_path = object_file_path.join(base_source_path);
                    let mut object_filename = object_path.file_name().unwrap().to_os_string();
                    object_filename.push(&obj_ext);
                    object_path.set_file_name(object_filename);

                    object_files.push(object_path);

                    // Don't create duplicate rules
                    if *artifact == LibraryArtifactType::JSLib && self.artifacts.contains(&LibraryArtifactType::Staticlib) { continue }

                    builder.add_step(&BuildStep::Build {
                        rule: cc_rule,
                        output: &object_files[object_files.len() - 1],
                        input: &[source.as_path()],
                        dependencies: additional_dependency_files,
                        options: &[("cflags", cflags)]
                    })?;
                }

                let artifact_file = traits::Target::artifact_file(self, project_build_dir, ArtifactType::Library(*artifact), target_triple)?;
                match *artifact {
                    LibraryArtifactType::Dynlib => {
                        builder.add_step(&BuildStep::Build {
                            rule: link_rule,
                            output: &artifact_file,
                            input: &(object_files.iter().chain(additional_artifact_files.iter())).map(|path| path.as_path()).collect::<Vec<&Path>>(),
                            dependencies: dependency_steps,
                            options: &[("linkerFlags", linker_flags)]
                        })?;
                    },
                    LibraryArtifactType::Staticlib => {
                        trace!("Creating staticlib for {} | object_files = {:?} | dependency_steps = {:?}", &self.name, &object_files, dependency_steps);
                        builder.add_step(&BuildStep::Build {
                            rule: &rules::AR,
                            output: &artifact_file,
                            input: &object_files.iter().map(|path| path.as_path()).collect::<Vec<&Path>>(),
                            dependencies: dependency_steps,
                            options: &[]
                        })?;
                    },
                    LibraryArtifactType::JSLib => {
                        match target_triple.operating_system {
                            OperatingSystem::Emscripten => {
                                builder.add_step(&BuildStep::Build {
                                    rule: &rules::JSLIB_C,
                                    output: &artifact_file,
                                    input: &(object_files.iter().chain(additional_artifact_files.iter())).map(|path| path.as_path()).collect::<Vec<&Path>>(),
                                    dependencies: dependency_steps,
                                    options: &[
                                        ("linkerFlags", linker_flags)
                                    ],
                                })?;
                            },
                            _ => {}
                        }
                    }
                    _ => unreachable!()
                }
                // if *artifact == LibraryArtifactType::Dynlib {
                // } else {
                // }

                let artifact_step = format!("{}$:{}$:{}", project_name, &self.name, artifact);
                builder.add_step(&BuildStep::Phony {
                    name: &artifact_step,
                    args: &[Scope::format_path(builder, artifact_file).to_str().unwrap()],
                    // args: &[&artifact_file.to_str().unwrap()],
                    dependencies: &[]
                })?;

                return Ok(artifact_step);
            },
            LibraryArtifactType::PkgConfig => {
                todo!("Pkg-config artifacts are coming soon")
            },
            LibraryArtifactType::Framework => todo!("Framework artifacts are coming soon"),
            LibraryArtifactType::XCFramework => todo!("XCFramework artifacts are coming soon"),
            _ => unreachable!("Invalid artifact")
        }
    }
}

impl traits::Library for Library {
    fn public_cflags(&self, project_base_dir: &Path, _: &Path, out: &mut Vec<String>, _: &mut Vec<PathBuf>) -> crate::Result<()> {
        out.extend(self.cflags.public.iter().cloned());
        out.extend(self.headers.public(project_base_dir)
            .map(|h| format!("-I{}", h.display())));
        Ok(())
    }

    fn library_artifacts(&self) -> Vec<LibraryArtifactType> {
        self.artifacts.clone()
    }

    fn additional_linker_flags<'a>(&'a self, _: &Path, _: &Triple, out: &mut Vec<String>) -> crate::Result<()> {
        out.extend(self.linker_flags.iter().cloned()); // would like to have a Cow here, but that would require redesigning some parts, so maybe in another release
        Ok(())
    }

    fn artifact_output_dir(&self,  project_build_dir: &std::path::Path, target_triple: &Triple) -> std::path::PathBuf {
        _ = target_triple; // todo: support cross-compiling in the future --> this is supported, target_triple isn't necessary since the project_build_dir has this variable
        project_build_dir.join("artifacts")
    }
}
