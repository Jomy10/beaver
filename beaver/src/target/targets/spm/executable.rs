use std::path::{Path, PathBuf};
use std::sync::{Arc, RwLock};

use target_lexicon::Triple;
use url::Url;

use crate::backend::BackendBuilder;
use crate::target::{ArtifactType, Dependency, ExecutableArtifactType, Language, Version};
use crate::traits::{self, TargetType};
use crate::Beaver;

#[derive(Debug)]
pub struct Executable {
    project_id: Option<usize>,
    id: Option<usize>,

    name: String,
}

impl Executable {
    pub(crate) fn new(name: String) -> Self {
        Self {
            project_id: None,
            id: None,
            name,
        }
    }
}

impl traits::Target for Executable {
    fn name(&self) -> &str {
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
        Language::Swift
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
        vec![ArtifactType::Executable(ExecutableArtifactType::Executable)]
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
        todo!()
    }

    #[doc = " Returns the target name"]
    fn register<Builder: BackendBuilder<'static>>(
        &self,
        project_name: &str,
        project_build_dir: &Path,
        project_base_dir: &Path,
        triple: &Triple,
        builder: Arc<RwLock<Builder>>,
        scope: &mut Builder::Scope,
        context: &Beaver,
    ) -> crate::Result<String> {
        todo!()
    }

    #[doc = " Debug attributes to print when using `--debug`"]
    fn debug_attributes(&self) -> Vec<(&'static str, String)> {
        vec![]
    }
}

impl traits::Executable for Executable {
    fn executable_artifacts(&self) -> Vec<ExecutableArtifactType> {
        vec![ExecutableArtifactType::Executable]
    }
}
