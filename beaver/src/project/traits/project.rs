use std::iter::zip;
use std::ops::Deref;
use std::path::Path;
use std::sync::{Arc, RwLock, RwLockWriteGuard};
use enum_dispatch::enum_dispatch;
use target_lexicon::Triple;

use crate::backend::BackendBuilder;
use crate::target::traits::AnyTarget;
use crate::target::TargetRef;
use crate::traits::Target;
use crate::{project, Beaver, BeaverError};

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

    #[doc(hidden)]
    /// A default implementation for registering targets. Should only be used internally
    ///
    /// Returns a guard to `builder` which can be dropped immediately
    /// The second returned are the step names of the targets
    fn register_targets<'a, Builder: BackendBuilder<'static>>(&self,
        triple: &Triple,
        builder: &'a Arc<RwLock<Builder>>,
        context: &Beaver
    ) -> crate::Result<(RwLockWriteGuard<'a, Builder>, Vec<String>)> {
        let targets = self.targets()?;

        let mut guard = builder.write().map_err(|err| BeaverError::BackendLockError(err.to_string()))?;
        let mut scopes: Vec<Builder::Scope> = (0..(*targets).len()).map(|_| guard.new_scope()).collect();
        drop(guard);

        let steps: Vec<String> = zip(targets.iter(), scopes.iter_mut()).map(|(target, scope)| {
            target.register(self.name(), self.base_dir(), self.build_dir(), triple, builder.clone(), scope, context)
        }).collect::<crate::Result<Vec<String>>>()?;
        // let steps: Vec<&str> = steps.iter().map(|str| str.as_str()).collect();

        let mut guard = builder.write().map_err(|err| BeaverError::BackendLockError(err.to_string()))?;
        for scope in scopes {
            guard.apply_scope(scope);
        }

        Ok((guard, steps))
    }

    fn as_mutable(&self) -> Option<&dyn MutableProject>;
}

pub trait MutableProject {
    fn add_target(&self, target: AnyTarget) -> crate::Result<usize>;
}

#[enum_dispatch(Project)]
#[derive(Debug)]
pub enum AnyProject {
    Beaver(project::beaver::Project),
    CMake(project::cmake::Project),
    Cargo(project::cargo::Project),
}
