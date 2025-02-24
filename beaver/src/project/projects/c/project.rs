use std::{path::PathBuf, sync::RwLock};
use crate::target::traits::Target;
use crate::{error::BeaverError, project, target};

pub struct Project {
    id: Option<usize>,
    name: String,
    base_dir: PathBuf,
    targets: RwLock<Vec<Box<dyn Target>>>
}

impl Project {
    pub fn new(
        name: String,
        base_dir: PathBuf
    ) -> Project {
        Project {
            id: None,
            name,
            base_dir,
            targets: RwLock::new(Vec::new())
        }
    }

    pub fn targets_mut<'a>(&'a self) -> crate::Result<std::sync::RwLockWriteGuard<'a, Vec<Box<dyn target::traits::Target>>>> {
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

    fn base_dir(&self) -> &std::path::Path {
        &self.base_dir
    }

    fn targets<'a>(&'a self) -> crate::Result<std::sync::RwLockReadGuard<'a, Vec<Box<dyn target::traits::Target>>>> {
        self.targets.read().map_err(|err| {
            BeaverError::TargetsReadError(err.to_string())
        })
    }
}

impl project::traits::MutableProject for Project {
    fn add_target(&self, target: Box<dyn target::traits::Target>) -> crate::Result<()> {
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
