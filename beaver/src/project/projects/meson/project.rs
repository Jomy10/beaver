use std::ops::Deref;
use std::path::{Path, PathBuf};
use std::sync::{Arc, RwLock};

use target_lexicon::Triple;

use crate::backend::{rules, BackendBuilder, BackendBuilderScope, BuildStep};
use crate::project::traits;
use crate::traits::{AnyTarget, MutableProject, Target};
use crate::{Beaver, BeaverError};

#[derive(Debug)]
pub struct Project {
    id: Option<usize>,
    name: String,
    base_dir: PathBuf,
    build_dir: PathBuf,
    targets: Vec<AnyTarget>,
}

impl Project {
    pub fn new(
        name: String,
        base_dir: PathBuf,
        build_dir: PathBuf,
        mut targets: Vec<AnyTarget>,
    ) -> Self {
        let mut i = 0;
        for target in &mut targets {
            target.set_id(i);
            i += 1;
        }
        Self {
            id: None,
            name,
            base_dir,
            build_dir,
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

    fn update_build_dir(&mut self, _: &Path) {
        panic!("Cannot set build directory for Meson project");
    }

    fn targets<'a>(&'a self) -> crate::Result<Box<dyn Deref<Target = Vec<AnyTarget>> + 'a>> {
        Ok(Box::new(&self.targets))
    }

    fn find_target(&self, name: &str) -> crate::Result<Option<usize>> {
        Ok(self.targets.iter().find(|target| target.name() == name).map(|target| target.id().unwrap()))
    }

    fn register<Builder: BackendBuilder<'static>>(
        &self,
        _scope: &rayon::Scope,
        triple: &Triple,
        builder: Arc<RwLock<Builder>>,
        context: &Arc<Beaver>,
    ) -> crate::Result<()> {
        let mut guard = builder.write().map_err(|err| BeaverError::BufferWriteError(err.to_string()))?;
        guard.add_rule_if_not_exists(&rules::MESON);
        drop(guard);

        let (mut guard, _) = self.register_targets(triple, &builder, context)?;

        let Some(project_build_dir_str) = self.build_dir.as_os_str().to_str() else {
            return Err(BeaverError::NonUTF8OsStr(self.build_dir.as_os_str().to_os_string()));
        };

        let mut scope = guard.new_scope();
        #[cfg(debug_assertions)] {
            scope.add_comment(&format!("Meson project: {}", self.name()))?;
        }
        scope.add_step(&BuildStep::Cmd {
            rule: &rules::MESON,
            name: &self.name,
            dependencies: &[],
            options: &[
                ("mesonBuildDir", project_build_dir_str),
                ("target", "")
            ]
        })?;

        guard.apply_scope(scope);

        Ok(())
    }

    fn as_mutable(&self) -> Option<&dyn MutableProject> {
        None
    }
}
