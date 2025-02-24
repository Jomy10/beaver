use std::{path::PathBuf, sync::{atomic::{AtomicIsize, Ordering}, RwLock, RwLockReadGuard, RwLockWriteGuard}};

use console::style;

use crate::{error::BeaverError, project::traits::Project, OptimizationMode};

pub struct Beaver {
    projects: RwLock<Vec<Box<dyn Project>>>,
    project_index: AtomicIsize,
    optimize_mode: OptimizationMode,
    build_dir: PathBuf,
    enable_color: bool
}

impl Beaver {
    pub fn new(enable_color: bool, optimize_mode: OptimizationMode) -> Beaver {
        Beaver {
            projects: RwLock::new(Vec::new()),
            project_index: AtomicIsize::new(-1),
            optimize_mode: optimize_mode,
            build_dir: std::env::current_dir().unwrap().join("build"),
            enable_color: enable_color,
        }
    }

    fn set_current_project_index(&self, idx: isize) {
        self.project_index.store(idx, Ordering::SeqCst);
    }

    pub fn current_project_index(&self) -> Option<isize> {
        let i = self.project_index.load(Ordering::SeqCst);
        if i < 0 {
            return None;
        } else {
            return Some(i);
        }
    }

    pub fn set_build_dir(&mut self, dir: PathBuf) {
        self.build_dir = dir;
    }

    pub fn projects(&self) -> Result<RwLockReadGuard<'_, Vec<Box<dyn Project>>>, BeaverError> {
        self.projects.read().map_err(|err| {
            BeaverError::ProjectsReadError(err.to_string())
        })
    }

    pub fn projects_mut(&self) -> Result<RwLockWriteGuard<'_, Vec<Box<dyn Project>>>, BeaverError> {
        self.projects.write().map_err(|err| {
            BeaverError::ProjectsWriteError(err.to_string())
        })
    }

    pub fn add_project(&self, project: Box<dyn Project>) -> Result<usize, BeaverError> {
        let mut project = project;
        let mut projects = self.projects_mut()?;
        let idx = projects.len();
        project.set_id(idx)?;
        projects.push(project);
        return Ok(idx);
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
                f.write_fmt(format_args!("  {}", target.name()));
                f.write_str("\n")?;
            }
        }

        return Ok(());
    }
}
