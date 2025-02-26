use std::path::Path;
use std::sync::{Arc, RwLock, RwLockReadGuard};
use target_lexicon::Triple;

use crate::backend::BackendBuilder;
use crate::target::traits::AnyTarget;
use crate::Beaver;

pub trait Project: Send + Sync + std::fmt::Debug {
    fn id(&self) -> Option<usize>;
    fn set_id(&mut self, new_id: usize) -> crate::Result<()>;
    fn name(&self) -> &str;
    fn base_dir(&self) -> &Path;
    fn build_dir(&self) -> &Path;
    fn update_build_dir(&mut self, new_base_build_dir: &Path);
    fn targets<'a>(&'a self) -> crate::Result<RwLockReadGuard<'a, Vec<AnyTarget>>>;

    fn register(&self,
        scope: &rayon::Scope,
        triple: &Triple,
        builder: Arc<RwLock<Box<dyn BackendBuilder>>>,
        context: &Beaver
    ) -> crate::Result<()>;
}

pub trait MutableProject {
    fn add_target(&self, target: AnyTarget) -> crate::Result<()>;
}
