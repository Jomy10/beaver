use std::path::{self, Path};
use std::sync::Arc;
use std::{path::PathBuf, sync::RwLock};
use log::trace;
use target_lexicon::Triple;

use crate::backend::{BackendBuilder, BackendBuilderScope, BuildStep};
use crate::target::traits::Target;
use crate::target::TargetRef;
use crate::traits::{AnyExecutable, AnyTarget, MutableProject};
use crate::Beaver;
use crate::{error::BeaverError, project};

#[derive(Debug)]
pub struct Project {
    id: Option<usize>,
    name: String,
    base_dir: PathBuf,
    build_dir: PathBuf,
    targets: RwLock<Vec<AnyTarget>>
}

// unsafe impl Send for Project {}

impl Project {
    pub fn new(
        name: String,
        base_dir: PathBuf,
        global_build_dir: &Path
    ) -> crate::Result<Project> {
        if !base_dir.exists() {
            return Err(BeaverError::ProjectPathDoesntExist { project: name, path: base_dir });
        }

        let build_dir = global_build_dir.join(&name);

        Ok(Project {
            id: None,
            name,
            base_dir: path::absolute(base_dir)?,
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

    fn default_executable(&self) -> crate::Result<TargetRef> {
        let targets = self.targets()?;
        let executables = targets.iter().filter_map(|target| {
            match target {
                AnyTarget::Library(_) => None,
                AnyTarget::Executable(exe) => Some(exe),
            }
        }).collect::<Vec<&AnyExecutable>>();

        match executables.len() {
            0 => Err(BeaverError::NoExecutable(self.name.to_string())),
            1 => Ok(executables[0].tref().unwrap()),
            2.. => Err(BeaverError::ManyExecutable {
                project: self.name.to_string(),
                targets: executables.into_iter().map(|exe| exe.name().to_string()).collect::<Vec<String>>()
            })
        }
    }

    fn targets<'a>(&'a self) -> crate::Result<Box<dyn std::ops::Deref<Target = Vec<AnyTarget>> + 'a>> {
        match self.targets.read() {
            Ok(val) => Ok(Box::new(val)),
            Err(err) => Err(BeaverError::TargetsReadError(err.to_string()))
        }
    }

    fn find_target(&self, name: &str) -> crate::Result<Option<usize>> {
        self.targets().map(|targets| {
            targets.iter().enumerate()
                .find(|target| {
                    target.1.name() == name
                })
                .map(|(id, _)| id)
        })
    }

    fn register<Builder: BackendBuilder<'static>>(&self,
        scope: &rayon::Scope,
        triple: &Triple,
        builder: Arc<RwLock<Builder>>,
        context: &Beaver
    ) -> crate::Result<()> {
        trace!("register {}", self.name);
        _ = scope; // TODO
        let steps: Vec<String> = self.targets()?.iter().map(|target| {
            target.register(&self.name, &self.base_dir, &self.build_dir, triple, builder.clone(), context)
        }).collect::<crate::Result<Vec<String>>>()?;
        let steps: Vec<&str> = steps.iter().map(|str| str.as_str()).collect();

        let mut guard = builder.write().map_err(|err| BeaverError::BackendLockError(err.to_string()))?;
        let mut scope = guard.new_scope();
        scope.add_step(&BuildStep::Phony {
            name: &self.name,
            args: &steps,
            dependencies: &[]
        })?;
        guard.apply_scope(scope);

        return Ok(());
    }

    fn as_mutable(&self) -> Option<&dyn MutableProject> {
        Some(self)
    }
}

impl project::traits::MutableProject for Project {
    fn add_target(&self, target: AnyTarget) -> crate::Result<usize> {
        let mut target = target;
        let mut targets = self.targets_mut()?;
        let target_id = targets.len();
        target.set_id(target_id);
        if let Some(project_id) = self.id {
            target.set_project_id(project_id);
        }
        targets.push(target);
        return Ok(target_id);
    }
}
