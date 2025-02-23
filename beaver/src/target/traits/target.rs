use std::path::{Path, PathBuf};

use target_lexicon::Triple;
use url::Url;
use crate::target::{Version, Language, ArtifactType, Dependency};

pub enum TargetType {
    Library,
    Executable,
}

pub trait Target {
    // General Info //
    fn name(&self) -> &str;
    fn description(&self) -> Option<&str>;
    fn homepage(&self) -> Option<&Url>;
    fn version(&self) -> Option<&Version>;
    fn license(&self) -> Option<&str>;
    fn language(&self) -> Language;

    // Identification //
    fn id(&self) -> Option<usize>;
    fn set_id(&mut self, new_id: usize);
    fn project_id(&self) -> Option<usize>;
    fn set_project_id(&mut self, new_id: usize);

    fn artifacts(&self) -> Vec<ArtifactType>;
    fn dependencies(&self) -> &Vec<Dependency>;

    fn r#type(&self) -> TargetType;

    fn artifact_output_dir(&self, project_build_dir: &Path, triple: &Triple) -> PathBuf;
    fn artifact_file(&self, project_build_dir: &Path, artifact: ArtifactType, triple: &Triple) -> crate::Result<PathBuf>;
}
