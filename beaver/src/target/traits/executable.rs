use std::path::Path;
use enum_dispatch::enum_dispatch;
use target_lexicon::Triple;

use crate::backend::BackendBuilder;
use crate::target::{ArtifactType, ExecutableArtifactType, traits::Target};

// #[enum_dispatch] // TODO
pub trait Executable: Target {
    fn run(&self, project_build_dir: &Path, args: &[String]) -> crate::Result<()> {
        let artifact_file = self.artifact_file(project_build_dir, ArtifactType::Executable(ExecutableArtifactType::Executable), &Triple::host())?;
        todo!("run {:?} {:?}", artifact_file, args)
    }
}

// TODO:
// #[enum_dispatch(Executable)]
#[derive(Debug)]
pub enum AnyExecutable {

}

#[allow(unused)]
impl Target for AnyExecutable {
    fn name(&self) ->  &str {
        todo!()
    }

    fn description(&self) -> Option<&str> {
        todo!()
    }

    fn homepage(&self) -> Option<&url::Url> {
        todo!()
    }

    fn version(&self) -> Option<&crate::target::Version> {
        todo!()
    }

    fn license(&self) -> Option<&str> {
        todo!()
    }

    fn language(&self) -> crate::target::Language {
        todo!()
    }

    fn id(&self) -> Option<usize> {
        todo!()
    }

    fn set_id(&mut self,new_id:usize) {
        todo!()
    }

    fn project_id(&self) -> Option<usize> {
        todo!()
    }

    fn set_project_id(&mut self,new_id:usize) {
        todo!()
    }

    fn artifacts(&self) -> Vec<ArtifactType> {
        todo!()
    }

    fn dependencies(&self) ->  &Vec<crate::target::Dependency> {
        todo!()
    }

    fn r#type(&self) -> super::TargetType {
        todo!()
    }

    fn artifact_output_dir(&self,project_build_dir: &Path,triple: &Triple) -> std::path::PathBuf {
        todo!()
    }

    fn artifact_file(&self,project_build_dir: &Path,artifact:ArtifactType,triple: &Triple) -> crate::Result<std::path::PathBuf> {
        todo!()
    }

    fn register<Builder: BackendBuilder<'static>>(&self,project_name: &str,project_base_dir: &Path,project_build_dir: &Path,triple: &Triple,builder: std::sync::Arc<std::sync::RwLock<Builder>>,context: &crate::Beaver) -> crate::Result<()> {
        todo!()
    }
}

impl Executable for AnyExecutable {
    fn run(&self,project_build_dir: &Path,args: &[String]) -> crate::Result<()>{
        let artifact_file = self.artifact_file(project_build_dir,ArtifactType::Executable(ExecutableArtifactType::Executable), &Triple::host())?;
        todo!("run {:?} {:?}",artifact_file,args)
    }
}
