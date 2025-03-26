use std::ops::Deref;
use std::path::{Path, PathBuf};
use std::sync::{Arc, RwLock};

use log::error;
use target_lexicon::Triple;
use std::process::Command;

use crate::backend::{rules, BackendBuilder, BackendBuilderScope, BuildStep};
use crate::traits::{self, AnyTarget, MutableProject, Target};
use crate::triple::TripleExt;
use crate::{tools, Beaver, BeaverError, OptimizationMode};

#[derive(Debug)]
pub struct Project {
    id: Option<usize>,
    name: String,
    base_dir: PathBuf,
    build_dir: PathBuf,
    /// The cache dir used by SPM
    cache_dir: Arc<PathBuf>,
    targets: Vec<AnyTarget>,
}

impl Project {
    pub fn new(
        name: String,
        base_dir: PathBuf,
        cache_dir: Arc<PathBuf>,
        targets: Vec<AnyTarget>,
        opt_mode: OptimizationMode,
        target_triple: &Triple
    ) -> Self {
        let build_dir = base_dir.join(".build")
            .join(target_triple.swift_name())
            .join(opt_mode.swift_name());
        let mut targets = targets;
        for i in 0..targets.len() {
            targets[i].set_id(i);
        }

        Self {
            id: None,
            name,
            base_dir,
            build_dir,
            cache_dir,
            targets,
        }
    }
}

impl traits::Project for Project {
    fn id(&self) -> Option<usize> {
        self.id
    }

    fn set_id(&mut self, new_id: usize) -> crate::Result<()> {
        self.id = Some(new_id);
        for target in &mut self.targets {
            target.set_id(new_id);
        }
        Ok(())
    }

    fn name(&self) -> &str {
        &self.name
    }

    fn base_dir(&self) -> &Path {
        &self.base_dir
    }

    fn build_dir(&self) -> &Path {
        &self.build_dir
    }

    fn update_build_dir(&mut self, _new_base_build_dir: &Path) {
        panic!("Cannot upate build_dir")
    }

    fn targets<'a>(&'a self) -> crate::Result<Box<dyn Deref<Target = Vec<AnyTarget>> + 'a>> {
        Ok(Box::new(&self.targets))
    }

    fn find_target(&self, name: &str) -> crate::Result<Option<usize>> {
        Ok(self.targets.iter().find(|target| target.name() == name)
            .map(|target| target.id().unwrap()))
    }

    fn register<Builder: BackendBuilder<'static>>(
        &self,
        _scope: &rayon::Scope,
        triple: &Triple,
        builder: Arc<RwLock<Builder>>,
        context: &Beaver,
    ) -> crate::Result<()> {
        let mut guard = builder.write().map_err(|err| BeaverError::BackendLockError(err.to_string()))?;
        guard.add_rule_if_not_exists(&rules::SPM_PROJECT);
        guard.add_rule_if_not_exists(&rules::SPM);
        let mut scope = guard.new_scope();
        drop(guard);
        #[cfg(debug_assertions)] { scope.add_comment(&self.name)?; }

        let base_abs = std::path::absolute(&self.base_dir)?;
        let Some(dir) = base_abs.to_str() else {
            return Err(BeaverError::NonUTF8OsStr(self.base_dir.as_os_str().to_os_string()));
        };

        let Some(cache_dir) = self.cache_dir.to_str() else {
            return Err(BeaverError::NonUTF8OsStr(self.cache_dir.as_os_str().to_os_string()));
        };

        for target in &self.targets {
            _ = target.register(
                &self.name,
                &base_abs,
                &self.build_dir,
                triple,
                builder.clone(),
                &mut scope,
                context
            )?;
        }

        scope.add_step(&BuildStep::Cmd {
            rule: &rules::SPM_PROJECT,
            name: &self.name,
            dependencies: &[],
            options: &[
                ("packageDir", dir),
                ("cacheDir", cache_dir)
            ],
        })?;

        let mut guard = builder.write().map_err(|err| BeaverError::BackendLockError(err.to_string()))?;
        guard.apply_scope(scope);

        Ok(())
    }

    fn clean(&self, context: &Beaver) -> crate::Result<()> {
        let base_dir_str = self.base_dir.to_string_lossy();
        context.cache()?.remove_context(&(context.optimize_mode.to_string() + ":" + base_dir_str.as_ref()))?;

        let output = Command::new(tools::swift.as_path())
            .args(["package", "clean"])
            .current_dir(&self.base_dir)
            .output()?;

        if !output.status.success() {
            error!("{}", String::from_utf8_lossy(&output.stderr));
            return Err(BeaverError::NonZeroExitStatus(output.status));
        }

        Ok(())
    }

    fn as_mutable(&self) -> Option<&dyn MutableProject> {
        None
    }
}
