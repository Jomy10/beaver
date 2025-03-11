use std::path::{Path, PathBuf};
use std::sync::{Arc, RwLock};

use target_lexicon::Triple;
use url::Url;

use crate::backend::{rules, BackendBuilder, BackendBuilderScope, BuildStep};
use crate::target::{ArtifactType, Dependency, Language, LibraryArtifactType, Version};
use crate::traits::{self, TargetType};
use crate::{Beaver, BeaverError};

#[derive(Debug)]
pub struct Library {
    project_id: Option<usize>,
    id: Option<usize>,

    cmake_id: String,
    name: String,
    language: Language,
    pub(crate) artifact: LibraryArtifactType,
    artifact_path: PathBuf,
    linker_flags: Vec<String>,
    cflags: Vec<String>,
    dependencies: Vec<Dependency>,
}

impl Library {
    pub fn new(
        cmake_id: String,
        name: String,
        language: Language,
        artifact: LibraryArtifactType,
        artifact_path: PathBuf,
        cflags: Vec<String>,
        linker_flags: Vec<String>,
        dependencies: Vec<Dependency>
    ) -> Self {
        Self {
            project_id: None,
            id: None,
            cmake_id,
            name,
            language,
            artifact,
            artifact_path,
            cflags,
            linker_flags,
            dependencies
        }
    }
}

impl Library {
    pub fn cmake_id(&self) -> &str {
        &self.cmake_id
    }
}

impl traits::Target for Library {
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
        vec![ArtifactType::Library(self.artifact)]
    }

    fn dependencies(&self) ->  &[Dependency] {
        &self.dependencies
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
        project_base_dir: &Path,
        project_build_dir: &Path,
        triple: &Triple,
        builder: Arc<RwLock<Builder>>,
        scope: &mut Builder::Scope,
        context: &Beaver
    ) -> crate::Result<String> {
        _ = triple; // TODO
        _ = context;
        _ = project_base_dir;

        let mut guard = builder.write()
            .map_err(|err| BeaverError::BackendLockError(err.to_string()))?;
        guard.add_rule_if_not_exists(&rules::NINJA);

        // let mut scope = guard.new_scope();
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

        let target_cmd = format!("{}$:{}", &target_cmd_name, self.artifact);
        scope.add_step(&BuildStep::Phony {
            name: &target_cmd,
            args: &[&target_cmd_name],
            dependencies: &[]
        })?;

        // let mut guard = builder.write().map_err(|err| BeaverError::BackendLockError(err.to_string()))?;
        // guard.apply_scope(scope);

        Ok(target_cmd_name)
    }

    /// Debug attributes to print when using `--debug`
    fn debug_attributes(&self) -> Vec<(&'static str,String)> {
        vec![]
    }
}

impl traits::Library for Library {
    fn library_artifacts(&self) -> Vec<LibraryArtifactType> {
        vec![self.artifact]
    }

    fn public_cflags(&self, _project_base_dir: &Path, collect_into: &mut Vec<String>) {
        collect_into.extend(self.cflags.iter().cloned())
    }

    fn additional_linker_flags(&self) -> Option<&Vec<String>> {
        Some(&self.linker_flags)
    }

    fn artifact_output_dir(&self, _project_build_dir: &Path, _triple: &Triple) -> PathBuf {
        self.artifact_path.parent().unwrap().to_path_buf()
    }
}
