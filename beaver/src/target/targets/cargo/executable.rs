use std::path::{Path, PathBuf};
use std::sync::{Arc, RwLock};

use target_lexicon::Triple;
use url::Url;

use crate::backend::{rules, BackendBuilder, BackendBuilderScope, BuildStep};
use crate::platform::executable_extension_for_os;
use crate::target::{ArtifactType, Dependency, ExecutableArtifactType, Language, Version};
use crate::traits::{self, TargetType};
use crate::{Beaver, BeaverError};

#[derive(Debug)]
pub struct Executable {
    project_id: Option<usize>,
    id: Option<usize>,

    name: String,
    description: Option<String>,
    homepage: Option<Url>,
    version: Option<Version>,
    license: Option<String>,
    artifacts: Vec<ExecutableArtifactType>,

    cargo_flags: Arc<Vec<String>>,
}

impl Executable {
    pub fn new(
        name: String,
        description: Option<String>,
        homepage: Option<Url>,
        version: Option<Version>,
        license: Option<String>,
        artifacts: Vec<ExecutableArtifactType>,
        cargo_flags: Arc<Vec<String>>,
    ) -> Self {
        Self {
            project_id: None,
            id: None,
            name,
            description,
            homepage,
            version,
            license,
            artifacts,
            cargo_flags,
        }
    }
}

impl traits::Target for Executable {
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

    fn artifacts(&self) -> Vec<ArtifactType> {
        self.artifacts.iter().map(|art| ArtifactType::Executable(*art)).collect()
    }

    fn dependencies(&self) -> &[Dependency] {
        &[]
    }

    fn r#type(&self) -> TargetType {
        TargetType::Executable
    }

    fn artifact_file(
        &self,
        project_build_dir: &Path,
        artifact: ArtifactType,
        triple: &Triple,
    ) -> crate::Result<PathBuf> {
        assert!(artifact.as_executable().unwrap() == ExecutableArtifactType::Executable);
        let ext: &str = executable_extension_for_os(&triple.operating_system)?.unwrap_or("");
        Ok(project_build_dir.join(format!("{}{}", self.name, ext)))
    }

    #[doc = " Returns the target name"]
    fn register<Builder: BackendBuilder<'static>>(
        &self,
        project_name: &str,
        workspace_dir: &Path,
        _project_build_dir: &Path,
        _triple: &Triple,
        _builder: Arc<RwLock<Builder>>,
        scope: &mut Builder::Scope,
        _context: &Beaver,
    ) -> crate::Result<String> {
        let Some(workspace_dir) = workspace_dir.to_str() else {
            return Err(BeaverError::NonUTF8OsStr(workspace_dir.as_os_str().to_os_string()));
        };

        let step_name = format!("{}:{}", project_name, self.name);

        scope.add_step(&BuildStep::Cmd {
            rule: &rules::CARGO,
            name: &step_name,
            dependencies: &[],
            options: &[
                ("workspaceDir", workspace_dir),
                ("target", &self.name),
                ("cargoArgs", &self.cargo_flags.join(" "))
            ],
        })?;

        for artifact in &self.artifacts {
            scope.add_step(&BuildStep::Cmd {
                rule: &rules::CARGO,
                name: &format!("{}:{}:{}", project_name, self.name, artifact),
                dependencies: &[],
                options: &[
                    ("workspaceDir", workspace_dir),
                    ("target", &self.name),
                    ("cargoArgs", &(format!("--bin {}", self.name) + self.cargo_flags.join(" ").as_str()))
                ]
            })?;
        }


        Ok(step_name)
    }

    #[doc = " Debug attributes to print when using `--debug`"]
    fn debug_attributes(&self) -> Vec<(&'static str, String)> {
        vec![]
    }
}

impl traits::Executable for Executable {
    fn executable_artifacts(&self) -> Vec<ExecutableArtifactType> {
        self.artifacts.clone()
    }
}
