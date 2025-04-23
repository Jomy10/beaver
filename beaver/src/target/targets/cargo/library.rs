use std::path::{Path, PathBuf};
use std::sync::{Arc, RwLock};

use target_lexicon::Triple;
use url::Url;

use crate::backend::{rules, BackendBuilder, BackendBuilderScope, BuildStep};
use crate::platform::{dynlib_extension_for_os, staticlib_extension_for_os};
use crate::target::{ArtifactType, Dependency, Language, LibraryArtifactType, Version};
use crate::traits::{self, TargetType};
use crate::{Beaver, BeaverError};

#[derive(Debug)]
pub struct Library {
    project_id: Option<usize>,
    id: Option<usize>,

    package_name: Arc<String>,
    name: String,
    description: Option<String>,
    homepage: Option<Url>,
    version: Option<Version>,
    license: Option<String>,
    artifacts: Vec<LibraryArtifactType>,

    cargo_flags: Arc<Vec<String>>,
}

impl Library {
    pub fn new(
        package_name: Arc<String>,
        name: String,
        description: Option<String>,
        homepage: Option<Url>,
        version: Option<Version>,
        license: Option<String>,
        artifacts: Vec<LibraryArtifactType>,
        cargo_flags: Arc<Vec<String>>
    ) -> Self {
        Self {
            project_id: None,
            id: None,
            package_name,
            name,
            description,
            homepage,
            version,
            license,
            artifacts,
            cargo_flags
        }
    }
}

impl traits::Target for Library {
    fn name(&self) -> &str {
        &self.name
    }

    fn description(&self) -> Option<&str> {
        self.description.as_deref()
    }

    fn homepage(&self) -> Option<&Url> {
        self.homepage.as_ref()
    }

    fn version(&self) -> Option<&Version> {
        self.version.as_ref()
    }

    fn license(&self) -> Option<&str> {
        self.license.as_deref()
    }

    fn language(&self) -> Language {
        Language::Rust
    }

    fn id(&self) -> Option<usize> {
        self.id
    }

    fn set_id(&mut self, new_id: usize) {
        self.id = Some(new_id)
    }

    fn project_id(&self) -> Option<usize> {
        self.project_id
    }

    fn set_project_id(&mut self, new_id: usize) {
        self.project_id = Some(new_id)
    }

    // TODO: trait to iterator
    fn artifacts(&self) -> Vec<ArtifactType> {
        self.artifacts
            .iter()
            .map(|art| ArtifactType::Library(*art))
            .collect()
    }

    fn dependencies(&self) -> &[Dependency] {
        &[]
    }

    fn r#type(&self) -> TargetType {
        TargetType::Library
    }

    fn artifact_file(
        &self,
        project_build_dir: &Path,
        artifact: ArtifactType,
        triple: &Triple,
    ) -> crate::Result<PathBuf> {
        let libart = artifact
            .as_library()
            .expect("should be library artifact (bug)");
        let ext: &str = match libart {
            LibraryArtifactType::Dynlib => dynlib_extension_for_os(&triple.operating_system)?,
            LibraryArtifactType::Staticlib => staticlib_extension_for_os(&triple.operating_system)?,
            LibraryArtifactType::RustLib => "rlib",
            LibraryArtifactType::RustDynlib => dynlib_extension_for_os(&triple.operating_system)?,
            LibraryArtifactType::PkgConfig
            | LibraryArtifactType::Framework
            | LibraryArtifactType::XCFramework
            | LibraryArtifactType::JSLib => unreachable!(),
        };
        Ok(project_build_dir.join(format!("lib{}.{}", self.name, ext)))
    }

    /// Returns the target name
    fn register<Builder: BackendBuilder<'static>>(
        &self,
        project_name: &str,
        workspace_dir: &Path,
        project_build_dir: &Path,
        triple: &Triple,
        _builder: Arc<RwLock<Builder>>,
        scope: &mut Builder::Scope,
        context: &Arc<Beaver>,
    ) -> crate::Result<String> {
        // let workspace_abs = std::path::absolute(workspace_dir)?;
        let Some(workspace_dir) = workspace_dir.to_str() else {
            return Err(BeaverError::NonUTF8OsStr(workspace_dir.as_os_str().to_os_string()));
        };

        let step_name = format!("{}$:{}", project_name, self.name);

        // ! rule should be registered in parent project
        scope.add_step(&BuildStep::Cmd {
            rule: &rules::CARGO,
            name: &step_name,
            dependencies: &[],
            options: &[
                ("workspaceDir", workspace_dir),
                ("target", &self.package_name),
                ("cargoArgs", &(self.cargo_flags.join(" ") + " --lib " + if context.color_enabled() { " --color always " } else { "" } + context.optimize_mode.cargo_flags().join(" ").as_str()))
            ]
        })?;

        for artifact in &self.artifacts {
            let abs_artifact = std::path::absolute(self.artifact_file(project_build_dir, ArtifactType::Library(*artifact), triple)?)?;
            let Some(abs_artifact) = abs_artifact.to_str() else {
                return Err(BeaverError::NonUTF8OsStr(abs_artifact.as_os_str().to_os_string()));
            };

            scope.add_step(&BuildStep::Phony {
                name: abs_artifact,
                args: &[&step_name],
                dependencies: &[],
            })?;

            scope.add_step(&BuildStep::Phony {
                name: &format!("{}$:{}$:{}", project_name, self.name, artifact),
                args: &[abs_artifact],
                dependencies: &[],
            })?;
        }

        Ok(step_name)
    }

    /// Debug attributes to print when using `--debug`
    fn debug_attributes(&self) -> Vec<(&'static str, String)> {
        vec![]
    }
}

impl traits::Library for Library {
    fn artifact_output_dir(&self, project_build_dir: &Path, _triple: &Triple) -> PathBuf {
        project_build_dir.to_path_buf()
    }

    fn library_artifacts(&self) -> Vec<LibraryArtifactType> {
        self.artifacts.clone()
    }

    // TODO: check
    fn additional_linker_flags(&self) -> Option<&Vec<String>> {
        None
    }

    fn public_cflags(&self, _project_base_dir: &Path, _project_build_dir: &Path, _collect_into: &mut Vec<String>, _: &mut Vec<PathBuf>) {}
}
