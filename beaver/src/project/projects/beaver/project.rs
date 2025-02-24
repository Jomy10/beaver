use std::path::Path;
use std::sync::Arc;
use std::{path::PathBuf, sync::RwLock};
use target_lexicon::Triple;

use crate::backend::BackendBuilder;
use crate::target::traits::Target;
use crate::traits::AnyTarget;
use crate::Beaver;
use crate::{error::BeaverError, project};

pub struct Project {
    id: Option<usize>,
    name: String,
    base_dir: PathBuf,
    build_dir: PathBuf,
    targets: RwLock<Vec<AnyTarget>>
}

unsafe impl Send for Project {}

impl Project {
    pub fn new(
        name: String,
        base_dir: PathBuf,
        build_dir: &Path
    ) -> crate::Result<Project> {
        if !base_dir.exists() {
            return Err(BeaverError::ProjectPathDoesntExist { project: name, path: base_dir });
        }

        let build_dir = build_dir.join(&name);

        Ok(Project {
            id: None,
            name,
            base_dir,
            build_dir,
            targets: RwLock::new(Vec::new())
        })
    }

    pub fn targets_mut<'a>(&'a self) -> crate::Result<std::sync::RwLockWriteGuard<'a, Vec<AnyTarget>>> {
        self.targets.write().map_err(|err| {
            BeaverError::TargetsWriteError(err.to_string())
        })
    }
}

impl project::traits::Project for Project {
    fn id(&self) -> Option<usize> {
        self.id
    }

    fn set_id(&mut self, new_id: usize) -> crate::Result<()> {
        self.id = Some(new_id);
        for target in self.targets_mut()?.iter_mut() {
            target.set_project_id(new_id);
        }
        return Ok(());
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

    fn update_build_dir(&mut self, new_dir: &Path) {
        self.build_dir = new_dir.join(&self.name);
    }

    fn targets<'a>(&'a self) -> crate::Result<std::sync::RwLockReadGuard<'a, Vec<AnyTarget>>> {
        self.targets.read().map_err(|err| {
            BeaverError::TargetsReadError(err.to_string())
        })
    }

    fn register(&self,
        scope: &rayon::Scope,
        triple: &Triple,
        builder: Arc<RwLock<Box<dyn BackendBuilder>>>,
        context: &Beaver
    ) -> crate::Result<()> {
        _ = scope; // TODO
        for target in self.targets()?.iter() {
            target.register(&self.name, &self.base_dir, &self.build_dir, triple, builder.clone(), context)?;
        }
        return Ok(());
    }
}

impl project::traits::MutableProject for Project {
    fn add_target(&self, target: AnyTarget) -> crate::Result<()> {
        let mut target = target;
        let mut targets = self.targets_mut()?;
        target.set_id(targets.len());
        if let Some(project_id) = self.id {
            target.set_project_id(project_id);
        }
        targets.push(target);
        return Ok(());
    }
}
