use std::fs;
use std::io::Write;
use std::path::PathBuf;
use std::sync::{Arc, RwLock, RwLockReadGuard, RwLockWriteGuard};
use std::sync::atomic::{AtomicIsize, Ordering};

use console::style;
use target_lexicon::Triple;
use utils::any::AsAny;

use crate::backend::ninja::NinjaBuilder;
use crate::backend::BackendBuilder;
use crate::OptimizationMode;
use crate::error::BeaverError;
use crate::project::traits::Project;
use crate::target::traits::{AnyTarget, Target};
use crate::target::TargetRef;

pub struct Beaver {
    projects: RwLock<Vec<Box<dyn Project>>>,
    project_index: AtomicIsize,
    pub(crate) optimize_mode: OptimizationMode,
    build_dir: PathBuf,
    enable_color: bool,
    target_triple: Triple,
}

impl Beaver {
    pub fn new(enable_color: bool, optimize_mode: OptimizationMode) -> Beaver {
        Beaver {
            projects: RwLock::new(Vec::new()),
            project_index: AtomicIsize::new(-1),
            optimize_mode,
            build_dir: std::env::current_dir().unwrap().join("build"),
            enable_color,
            target_triple: Triple::host()
        }
    }

    fn set_current_project_index(&self, idx: usize) {
        self.project_index.store(idx as isize, Ordering::SeqCst);
    }

    pub fn current_project_index(&self) -> Option<usize> {
        let i = self.project_index.load(Ordering::SeqCst);
        if i < 0 {
            return None;
        } else {
            return Some(i as usize);
        }
    }

    pub fn set_build_dir(&mut self, dir: PathBuf) -> crate::Result<()> {
        if self.current_project_index() != None {
            return Err(BeaverError::SetBuildDirAfterAddProject);
        }

        self.build_dir = dir;
        // Not needed because of check
        // for project in self.projects_mut()?.iter_mut() {
        //     project.update_build_dir(&self.build_dir);
        // }
        return Ok(());
    }

    pub fn projects(&self) -> crate::Result<RwLockReadGuard<'_, Vec<Box<dyn Project>>>> {
        self.projects.read().map_err(|err| {
            BeaverError::ProjectsReadError(err.to_string())
        })
    }

    pub fn projects_mut(&self) -> crate::Result<RwLockWriteGuard<'_, Vec<Box<dyn Project>>>> {
        self.projects.write().map_err(|err| {
            BeaverError::ProjectsWriteError(err.to_string())
        })
    }

    pub fn add_project(&self, project: Box<dyn Project>) -> crate::Result<usize> {
        let mut project = project;
        let mut projects = self.projects_mut()?;
        let idx = projects.len();
        project.set_id(idx)?;
        projects.push(project);
        self.set_current_project_index(idx);
        return Ok(idx);
    }

    pub fn with_project_and_target<S>(
        &self,
        target: &TargetRef,
        cb: impl FnOnce(&Box<dyn Project>, &AnyTarget) -> crate::Result<S>
    ) -> crate::Result<S> {
        let projects = self.projects()?;
        let project = projects.get(target.project).expect("Invalid TargetRef"); // We assume a TargetRef is always acquired for a target that exists
        let targets = project.targets()?;
        let target = targets.get(target.target).expect("Invalid TargetRef");
        return cb(project, target).map_err(|err| err.into());
    }

    fn build_file(&self) -> PathBuf {
        self.build_dir.join(format!("build.{}.{}.ninja", self.optimize_mode, self.target_triple))
    }

    pub fn create_build_file(&self) -> crate::Result<()> {
        let ninja_builder: Arc<RwLock<Box<dyn BackendBuilder>>> = Arc::new(RwLock::new(Box::new(NinjaBuilder::new())));
        let error: RwLock<Option<BeaverError>> = RwLock::new(None);
        let projects = self.projects()?;
        rayon::scope(|s| {
            for project in projects.iter() {
                s.spawn(|s| match project.register(s, &self.target_triple, ninja_builder.clone(), &self) {
                    Err(err) => *error.write().expect("Error accessing buffer for storing error") = Some(err),
                    Ok(()) => {}
                });
                if error.read().expect("Error accessing buffer for storing error").is_some() {
                    break;
                }
            }
        });

        if let Some(err) = error.write().expect("Error accessing buffer for storing error").take() {
            return Err(err);
        }

        let builder = Arc::try_unwrap(ninja_builder).unwrap_or_else(|_| panic!("Arc shouldn't be referenced anymore"));
        let builder = builder.into_inner().map_err(|err| BeaverError::BackendLockError(err.to_string()))?;
        let builder = Box::into_raw(builder);
        let builder = unsafe { Box::from_raw(builder as *mut NinjaBuilder) };
        let output = builder.build();
        let output_file = self.build_file();

        let mut file = fs::File::options()
            .write(true)
            .create(true)
            .open(output_file)
            .map_err(|err| BeaverError::BuildFileWriteError(err))?;
        file.write(output.as_bytes())
            .map_err(|err| BeaverError::BuildFileWriteError(err))?;

        return Ok(());
    }
}

impl std::fmt::Display for Beaver {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        let projects = self.projects.read().unwrap();
        for project in projects.iter() {
            if project.id().unwrap() == self.project_index.load(Ordering::SeqCst) as usize && self.enable_color {
                f.write_fmt(format_args!("{}", style(project.name()).blue()))?;
            } else {
                f.write_str(project.name())?;
            }
            f.write_str("\n")?;

            for target in project.targets().unwrap().iter() {
                f.write_fmt(format_args!("  {}", target.name()))?;
                f.write_str("\n")?;
            }
        }

        return Ok(());
    }
}
