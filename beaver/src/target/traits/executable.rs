use std::path::Path;
use target_lexicon::Triple;

use crate::target::{ArtifactType, ExecutableArtifactType, traits::Target};

pub trait Executable: Target {
    fn run(&self, project_build_dir: &Path, args: &[String]) -> crate::Result<()> {
        let artifact_file = self.artifact_file(project_build_dir, ArtifactType::Executable(ExecutableArtifactType::Executable), &Triple::host())?;
        todo!("run {:?} {:?}", artifact_file, args)
    }
}
