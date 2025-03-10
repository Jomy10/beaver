use std::ops::Deref;
use std::path::Path;
use std::sync::{Arc, RwLock};
use enum_dispatch::enum_dispatch;
use target_lexicon::Triple;

use crate::backend::BackendBuilder;
use crate::target::traits::AnyTarget;
use crate::target::TargetRef;
use crate::{project, Beaver};

#[enum_dispatch]
pub trait Project: Send + Sync + std::fmt::Debug {
    fn id(&self) -> Option<usize>;
    fn set_id(&mut self, new_id: usize) -> crate::Result<()>;
    fn name(&self) -> &str;
    fn base_dir(&self) -> &Path;
    fn build_dir(&self) -> &Path;
    fn update_build_dir(&mut self, new_base_build_dir: &Path);
    fn targets<'a>(&'a self) -> crate::Result<Box<dyn Deref<Target = Vec<AnyTarget>> + 'a>>;
    fn find_target(&self, name: &str) -> crate::Result<Option<usize>>;
    fn default_executable(&self) -> crate::Result<TargetRef>;
    fn register<Builder: BackendBuilder<'static>>(&self,
        scope: &rayon::Scope,
        triple: &Triple,
        builder: Arc<RwLock<Builder>>,
        context: &Beaver
    ) -> crate::Result<()>;

    fn as_mutable(&self) -> Option<&dyn MutableProject>;
}

pub trait MutableProject {
    fn add_target(&self, target: AnyTarget) -> crate::Result<usize>;
}

#[enum_dispatch(Project)]
#[derive(Debug)]
pub enum AnyProject {
    Beaver(project::beaver::Project),
    CMake(project::cmake::Project)
}
