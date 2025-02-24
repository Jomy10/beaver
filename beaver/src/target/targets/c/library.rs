use beaver_macros::init_descriptor;
use target_lexicon::Triple;

use crate::platform::{dynlib_extension_for_os, staticlib_extension_for_os};
use crate::target::parameters::{DefaultArgument, Files, Flags, Headers};
use crate::target::traits::TargetType;
use crate::target::{traits, ArtifactType, Dependency, Language, LibraryArtifactType, Version};
use crate::BeaverError;

#[init_descriptor]
pub struct Library {
    #[descriptor_value(None)]
    id: Option<usize>,
    #[descriptor_value(None)]
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
    linker_flags: Flags,

    artifacts: Vec<LibraryArtifactType>,
    dependencies: Vec<Dependency>,
}

impl Library {
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
        linker_flags: Flags,
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

    pub fn linker_flags(&self) -> &Flags {
        &self.linker_flags
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
        // self.artifact_output_dir(project_build_dir).join()
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
}
