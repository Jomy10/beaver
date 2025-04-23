use std::path::{Path, PathBuf};
use std::sync::{Arc, RwLock};

use target_lexicon::Triple;
use url::Url;

use crate::backend::BackendBuilder;
use crate::platform::executable_extension_for_os;
use crate::target::{ArtifactType, Dependency, ExecutableArtifactType, Language, Version};
use crate::traits::{self, TargetType};
use crate::Beaver;

#[derive(Debug)]
pub struct Executable {
    project_id: Option<usize>,
    id: Option<usize>,

    name: String,

    cache_dir: Arc<PathBuf>,
}

impl Executable {
    pub(crate) fn new(name: String, cache_dir: Arc<PathBuf>) -> Self {
        Self {
            project_id: None,
            id: None,
            name,
            cache_dir
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
        let ext = match artifact.as_executable().unwrap() {
            ExecutableArtifactType::Executable => executable_extension_for_os(&triple.operating_system)?.map(|ext| String::from(".") + ext),
            ExecutableArtifactType::App => Some(".app".to_string()),
        };
        Ok(if let Some(ext) = &ext {
            project_build_dir.join(self.name.clone() + ext)
        } else {
            project_build_dir.join(&self.name)
        })
    }

    #[doc = " Returns the target name"]
    fn register<Builder: BackendBuilder<'static>>(
        &self,
        project_name: &str,
        project_build_dir: &Path,
        project_base_dir: &Path,
        triple: &Triple,
        _builder: Arc<RwLock<Builder>>,
        scope: &mut Builder::Scope,
        _context: &Arc<Beaver>,
    ) -> crate::Result<String> {
        let artifact_file = std::path::absolute(self.artifact_file(project_build_dir, ArtifactType::Executable(ExecutableArtifactType::Executable), triple)?)?;
        super::register_target(scope, project_name, &self.name, project_base_dir, &artifact_file, ExecutableArtifactType::Executable, &self.cache_dir, None)
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
