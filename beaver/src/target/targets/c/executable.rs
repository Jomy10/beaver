use std::path::{Path, PathBuf};
use std::sync::{Arc, RwLock};

use log::warn;
use target_lexicon::Triple;

use crate::backend::{BackendBuilder, BackendBuilderScope, BuildStep};
use crate::platform::executable_extension_for_os;
use crate::target::parameters::{DefaultArgument, Files, Flags, Headers};
use crate::target::{traits, ArtifactType, Dependency, ExecutableArtifactType, Language, Version};
use crate::traits::TargetType;
use crate::Beaver;

use super::{CTarget, TargetDescriptor};

#[derive(Debug)]
pub struct Executable {
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

    artifacts: Vec<ExecutableArtifactType>,
    dependencies: Vec<Dependency>,
}

impl Executable {
    pub fn new_desc(desc: TargetDescriptor<ExecutableArtifactType>) -> Executable {
        Executable::new(
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
        artifacts: DefaultArgument<Vec<ExecutableArtifactType>>,
        dependencies: Vec<Dependency>,
    ) -> Executable {
        Executable {
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
            artifacts: artifacts.or_default(vec![ExecutableArtifactType::Executable]),
            dependencies
        }
    }
}


impl traits::Target for Executable {
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
        self.artifacts.iter().map(|a| ArtifactType::Executable(*a)).collect()
    }

    fn dependencies(&self) -> &[crate::target::Dependency] {
        &self.dependencies
    }

    fn r#type(&self) -> TargetType {
        TargetType::Executable
    }

    fn artifact_file(&self, project_build_dir: &Path, artifact: ArtifactType, target_triple: &Triple) -> crate::Result<PathBuf> {
        let dir = self.artifact_output_dir(project_build_dir, target_triple);
        return match artifact {
            ArtifactType::Executable(exe) => match exe {
                ExecutableArtifactType::Executable => {
                    let mut path = dir.join(&self.name);
                    if let Ok(Some(ext)) = executable_extension_for_os(&target_triple.operating_system) {
                        path.set_extension(ext);
                    }
                    Ok(path)
                },
                ExecutableArtifactType::App => {
                    let mut path = dir.join(&self.name);
                    path.set_extension("app");
                    Ok(path)
                }
            },
            ArtifactType::Library(_) => panic!("bug"),
        }
    }

    fn register<Builder: BackendBuilder<'static>>(&self,
        project_name: &str,
        project_base_dir: &Path,
        project_build_dir: &Path,
        target_triple: &Triple,
        builder: Arc<RwLock<Builder>>,
        scope: &mut Builder::Scope,
        context: &crate::Beaver
    ) -> crate::Result<String> {
        CTarget::register_impl(
            self,
            project_name,
            project_base_dir,
            project_build_dir,
            target_triple,
            builder,
            scope,
            &[self.cc_rule(), self.link_rule()],
            context
        )
    }

    fn debug_attributes(&self) -> Vec<(&'static str, String)> {
        vec![
            ("cflags", format!("{:?}", self.cflags)),
            ("headers", format!("{:?}", self.headers)),
            ("linker_flags", self.linker_flags.join(", ")),
        ]
    }
}

impl CTarget for Executable {
    type TargetArtifactType = ExecutableArtifactType;

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

    /// All linker flags used by this executable when linking
    fn linker_flags<'a>(&self, dependencies: impl Iterator<Item = &'a Dependency>, languages: impl Iterator<Item = &'a Language>, triple: &Triple, context: &Beaver) -> crate::Result<(Vec<String>, Vec<PathBuf>)> {
        let mut flags: Vec<String> = self.linker_flags.clone();

        let mut additional_files = Vec::new();
        for dependency in dependencies {
            dependency.linker_flags(triple, context, &mut flags, &mut additional_files)?;
        }
        for lang in languages {
            let Some(lang_flags) = Language::linker_flags(*lang, self.language, triple) else { continue };
            flags.extend(lang_flags.iter().map(|str| str.to_string()))
        }

        flags.extend(context.optimize_mode.linker_flags().iter().map(|str| str.to_string()));

        return Ok((flags, additional_files));
    }

    fn register_artifact<Scope: BackendBuilderScope>(
        &self,
        artifact: &Self::TargetArtifactType,
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
            ExecutableArtifactType::Executable => {
                let mut object_files: Vec<PathBuf> = additional_artifact_files.to_vec();
                let sources = self.sources.resolve(project_base_dir)?;
                if sources.len() == 0 { warn!("No sources in C::Executable {}", self.name); }
                for source in sources {
                    let base_source_path = source.as_path().strip_prefix(project_base_dir)
                        .expect("Unexpected error: couldn't strip prefix form source path");
                    let mut object_path = object_file_path.join(base_source_path);
                    let mut object_filename = object_path.file_name().unwrap().to_os_string();
                    object_filename.push(".o");
                    object_path.set_file_name(object_filename);

                    object_files.push(object_path);

                    builder.add_step(&BuildStep::Build {
                        rule: cc_rule,
                        output: &object_files[object_files.len() - 1],
                        input: &[source.as_path()],
                        dependencies: additional_dependency_files,
                        options: &[("cflags", cflags)]
                    })?;
                }

                let artifact_file = traits::Target::artifact_file(self, project_build_dir, ArtifactType::Executable(*artifact), target_triple)?;
                builder.add_step(&BuildStep::Build {
                    rule: link_rule,
                    output: &artifact_file,
                    input: &object_files.iter().map(|path| path.as_path()).collect::<Vec<&Path>>(),
                    dependencies: dependency_steps,
                    options: &[("linkerFlags", linker_flags)]
                })?;

                let artifact_step = format!("{}$:{}$:{}", project_name, &self.name, artifact);
                builder.add_step(&BuildStep::Phony {
                    name: &artifact_step,
                    args: &[Scope::format_path(builder, artifact_file).to_str().unwrap()],
                    // args: &[&artifact_file.to_str().unwrap()],
                    dependencies: &[]
                })?;

                return Ok(artifact_step);
            },
            ExecutableArtifactType::App => {
                todo!("App have a dependency on executable and then construct app")
            }
        }
    }
}

impl traits::Executable for Executable {
    fn executable_artifacts(&self) -> Vec<ExecutableArtifactType> {
        self.artifacts.clone()
    }
}

impl Executable {
    fn artifact_output_dir(&self,  project_build_dir: &Path, target_triple: &Triple) -> PathBuf {
        _ = target_triple; // todo: support cross-compiling in the future
        project_build_dir.join("artifacts")
    }
}
