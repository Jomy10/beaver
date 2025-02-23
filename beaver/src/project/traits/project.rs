use std::path::Path;
use std::sync::RwLockReadGuard;
use crate::target::traits::Target;

pub trait Project {
    fn id(&self) -> Option<usize>;
    fn set_id(&mut self, new_id: usize);
    fn name(&self) -> &str;
    fn base_dir(&self) -> &Path;
    fn targets<'a>(&'a self) -> crate::Result<RwLockReadGuard<'a, Vec<Box<dyn Target>>>>;
}

pub trait MutableProject {
    fn add_target(&self, target: Box<dyn Target>) -> crate::Result<()>;
}
