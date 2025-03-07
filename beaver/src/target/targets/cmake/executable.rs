use std::path::{Path, PathBuf};
use std::sync::{Arc, RwLock};

use log::trace;
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

    cmake_id: String,
    name: String,
    language: Language,
    artifact: ExecutableArtifactType,
    artifact_path: PathBuf,
}

impl Executable {
    pub fn new(
        cmake_id: String,
        name: String,
        language: Language,
        artifact: ExecutableArtifactType,
        artifact_path: PathBuf,
    ) -> Self {
        Self {
            project_id: None,
            id: None,
            cmake_id,
            name,
            language,
            artifact,
            artifact_path,
        }
    }
}

impl Executable {
    pub fn cmake_id(&self) -> &str {
        &self.cmake_id
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
        None
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
        vec![ArtifactType::Executable(self.artifact)]
    }

    fn dependencies(&self) ->  &[Dependency] {
        &[]
    }

    fn r#type(&self) -> TargetType {
        TargetType::Library
    }

    fn artifact_file(&self, _project_build_dir: &Path, _artifact: ArtifactType, _triple: &Triple) -> crate::Result<PathBuf> {
        Ok(self.artifact_path.clone())
    }

    fn register<Builder: BackendBuilder<'static>>(
        &self,
        project_name: &str,
        _project_base_dir: &Path,
        project_build_dir: &Path,
        triple: &Triple,
        builder: Arc<RwLock<Builder>>,
        _context: &Beaver
    ) -> crate::Result<String> {
        trace!("Register CMake Exe: {}", self.name);
        _ = triple; // TODO
        let mut guard = builder.write()
            .map_err(|err| BeaverError::BackendLockError(err.to_string()))?;
        guard.add_rule_if_not_exists(&rules::NINJA);
        let mut scope = guard.new_scope();
        drop(guard);

        #[cfg(debug_assertions)] {
            scope.add_comment(&format!("{}:{}", &self.name, self.artifact))?;
        }

        let Some(project_build_dir_str) = project_build_dir.as_os_str().to_str() else {
            return Err(BeaverError::NonUTF8OsStr(project_build_dir.as_os_str().to_os_string()));
        };

        let target_cmd_name = format!("{}$:{}", project_name, &self.name);

        scope.add_step(&BuildStep::Cmd {
            rule: &rules::NINJA,
            name: &target_cmd_name,
            dependencies: &[],
            options: &[
                ("ninjaBaseDir", project_build_dir_str),
                ("ninjaFile", "build.ninja"),
                ("targets", &self.name)
            ]
        })?;

        let artifact_cmd = format!("{}$:{}", &target_cmd_name, self.artifact);
        scope.add_step(&BuildStep::Phony {
            name: &artifact_cmd,
            args: &[&target_cmd_name],
            dependencies: &[]
        })?;

        let mut guard = builder.write().map_err(|err| BeaverError::BackendLockError(err.to_string()))?;
        guard.apply_scope(scope);

        Ok(target_cmd_name)
    }

    /// Debug attributes to print when using `--debug`
    fn debug_attributes(&self) -> Vec<(&'static str,String)> {
        vec![]
    }
}

impl traits::Executable for Executable {
    fn executable_artifacts(&self) ->  Vec<ExecutableArtifactType> {
        vec![self.artifact]
    }
}
