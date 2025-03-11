use std::path::Path;
use enum_dispatch::enum_dispatch;
use target_lexicon::Triple;

use crate::target;
use crate::target::{ArtifactType, ExecutableArtifactType, traits::Target};

#[enum_dispatch]
pub trait Executable: Target {
    fn run(&self, project_build_dir: &Path, args: &[String]) -> crate::Result<()> {
        let artifact_file = self.artifact_file(project_build_dir, ArtifactType::Executable(ExecutableArtifactType::Executable), &Triple::host())?;
        todo!("run {:?} {:?}", artifact_file, args)
    }

    fn executable_artifacts(&self) -> Vec<ExecutableArtifactType>;

    fn default_executable_artifact(&self) -> Option<ExecutableArtifactType> {
        let artifacts = self.executable_artifacts();
        if artifacts.contains(&ExecutableArtifactType::Executable) {
            return Some(ExecutableArtifactType::Executable);
        } else if artifacts.contains(&ExecutableArtifactType::App) {
            return Some(ExecutableArtifactType::App);
        } else {
            return None;
        }
    }
}

#[enum_dispatch(Target)]
#[enum_dispatch(Executable)]
#[derive(Debug)]
pub enum AnyExecutable {
    C(target::c::Executable),
    CMake(target::cmake::Executable),
    Cargo(target::cargo::Executable),
}
