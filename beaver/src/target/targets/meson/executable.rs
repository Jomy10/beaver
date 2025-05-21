use std::path::{Path, PathBuf};
use std::sync::{Arc, RwLock};

use target_lexicon::Triple;
use url::Url;

use crate::backend::{rules, BackendBuilder, BackendBuilderScope, BuildStep};
use crate::target::{traits, ArtifactType, Dependency, ExecutableArtifactType, Language, Version};
use crate::traits::TargetType;
use crate::{Beaver, BeaverError};

#[derive(Debug)]
pub struct Executable {
    project_id: Option<usize>,
    id: Option<usize>,

    meson_id: String,
    name: String,
    version: Version,
    language: Language,
    artifact_type: ExecutableArtifactType,
    artifact: PathBuf,
}

impl Executable {
    pub fn new(
        meson_id: String,
        name: String,
        version: Version,
        language: Language,
        artifact_type: ExecutableArtifactType,
        artifact: PathBuf,
    ) -> Self {
        Self {
            project_id: None,
            id: None,
            meson_id,
            name,
            version,
            language,
            artifact_type,
            artifact,
        }
    }
}

impl Executable {
    pub fn meson_id(&self) -> &str {
        &self.meson_id
    }
}

impl traits::Target for Executable {
    fn name(&self) ->  &str {
        &self.name
    }

    fn description(&self) -> Option<&str> {
        None
    }

    fn homepage(&self) -> Option<&Url> {
        None
    }

    fn version(&self) -> Option<&Version> {
        Some(&self.version)
    }

    fn license(&self) -> Option<&str> {
        None
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

    fn artifacts(&self) -> Vec<ArtifactType> {
        vec![ArtifactType::Executable(self.artifact_type)]
    }

    fn dependencies(&self) ->  &[Dependency] {
        &[]
    }

    fn r#type(&self) -> TargetType {
        TargetType::Executable
    }

    fn artifact_file(&self, _project_build_dir: &Path, _artifact: ArtifactType, _triple: &Triple) -> crate::Result<PathBuf> {
        Ok(self.artifact.clone())
    }

    fn register<Builder: BackendBuilder<'static>>(
        &self,
        project_name: &str,
        _project_base_dir: &Path,
        project_build_dir: &Path,
        triple: &Triple,
        _builder: Arc<RwLock<Builder>>,
        scope: &mut Builder::Scope,
        _context: &Arc<Beaver>
    ) -> crate::Result<String> {
        #[cfg(debug_assertions)] {
            scope.add_comment(&format!("{}:{}", &self.name, self.artifact_type))?;
        }

        let Some(project_build_dir_str) = project_build_dir.as_os_str().to_str() else {
            return Err(BeaverError::NonUTF8OsStr(project_build_dir.as_os_str().to_os_string()));
        };

        let target_cmd_name = format!("{}$:{}", project_name, &self.name);

        scope.add_step(&BuildStep::Cmd {
            rule: &rules::MESON,
            name: &target_cmd_name,
            dependencies: &[],
            options: &[
                ("mesonBuildDir", project_build_dir_str),
                ("target", &self.name)
            ]
        })?;

        let target_cmd = format!("{}$:{}", &target_cmd_name, self.artifact_type);
        scope.add_step(&BuildStep::Phony {
            name: &target_cmd,
            args: &[&target_cmd_name],
            dependencies: &[]
        })?;

        let artifact_file = self.artifact_file(project_build_dir, ArtifactType::Executable(self.artifact_type), triple)?;
        let artifact_file = crate::path::path_to_str(&artifact_file)?;
        scope.add_step(&BuildStep::Phony {
            name: artifact_file,
            args: &[&target_cmd_name],
            dependencies: &[],
        })?;

        Ok(target_cmd_name)
    }

    /// Debug attributes to print when using `--debug`
    fn debug_attributes(&self) -> Vec<(&'static str,String)> {
        vec![
            ("meson_id", self.meson_id.clone())
        ]
    }
}

impl traits::Executable for Executable {
    fn executable_artifacts(&self) ->  Vec<ExecutableArtifactType> {
        vec![self.artifact_type]
    }
}
