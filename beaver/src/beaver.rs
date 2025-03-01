use std::{env, fs};
use std::io::Write;
use std::path::PathBuf;
use std::sync::{Arc, RwLock, RwLockReadGuard, RwLockWriteGuard};
use std::sync::atomic::{AtomicIsize, Ordering};

use console::style;
use target_lexicon::Triple;

use crate::backend::ninja::{NinjaBuilder, NinjaRunner};
use crate::backend::BackendBuilder;
use crate::traits::AnyProject;
use crate::OptimizationMode;
use crate::error::BeaverError;
use crate::project::traits::Project;
use crate::target::traits::{AnyTarget, Target};
use crate::target::TargetRef;

/// All methods of this struct are immutable because this struct ensures all calls to its
/// methods are thread safe
#[derive(Debug)]
pub struct Beaver {
    projects: RwLock<Vec<AnyProject>>,
    project_index: AtomicIsize,
    pub(crate) optimize_mode: OptimizationMode,
    build_dir: RwLock<PathBuf>,
    enable_color: bool,
    target_triple: Triple,
    verbose: bool
}

impl Beaver {
    pub fn new(enable_color: Option<bool>, optimize_mode: OptimizationMode) -> Beaver {
        Beaver {
            projects: RwLock::new(Vec::new()),
            project_index: AtomicIsize::new(-1),
            optimize_mode,
            build_dir: RwLock::new(std::env::current_dir().unwrap().join("build")),
            enable_color: enable_color.unwrap_or(true), // TODO: derive from isatty or set instance var to optional
            target_triple: Triple::host(),
            verbose: false
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

    pub fn set_build_dir(&self, dir: PathBuf) -> crate::Result<()> {
        if self.current_project_index() != None {
            return Err(BeaverError::SetBuildDirAfterAddProject);
        }

        *self.build_dir.write().map_err(|err| BeaverError::LockError(err.to_string()))? = dir;
        // Not needed because of check
        // for project in self.projects_mut()?.iter_mut() {
        //     project.update_build_dir(&self.build_dir);
        // }
        return Ok(());
    }

    pub fn get_build_dir(&self) -> crate::Result<RwLockReadGuard<'_, PathBuf>> {
        // TODO: freeze build dir
        self.build_dir.read().map_err(|err| BeaverError::LockError(err.to_string()))
    }

    pub fn projects(&self) -> crate::Result<RwLockReadGuard<'_, Vec<AnyProject>>> {
        self.projects.read().map_err(|err| {
            BeaverError::ProjectsReadError(err.to_string())
        })
    }

    fn projects_mut(&self) -> crate::Result<RwLockWriteGuard<'_, Vec<AnyProject>>> {
        self.projects.write().map_err(|err| {
            BeaverError::ProjectsWriteError(err.to_string())
        })
    }

    pub fn add_project(&self, project: impl Into<AnyProject>) -> crate::Result<usize> {
        let mut project: AnyProject = project.into();
        let mut projects = self.projects_mut()?;
        let idx = projects.len();
        project.set_id(idx)?;
        projects.push(project);
        drop(projects);
        self.set_current_project_index(idx);
        return Ok(idx);
    }

    pub fn with_project_and_target<S>(
        &self,
        target: &TargetRef,
        cb: impl FnOnce(&AnyProject, &AnyTarget) -> crate::Result<S>
    ) -> crate::Result<S> {
        let projects = self.projects()?;
        let project = projects.get(target.project).expect("Invalid TargetRef"); // We assume a TargetRef is always acquired for a target that exists
        let targets = project.targets()?;
        let target = targets.get(target.target).expect("Invalid TargetRef");
        return cb(project, target).map_err(|err| err.into());
    }

    pub fn with_project_named<S>(
        &self,
        project_name: &str,
        cb: impl FnOnce(&AnyProject) -> crate::Result<S>
    ) -> crate::Result<S> {
        let projects = self.projects()?;
        let Some(project) = projects.iter().find(|project| project.name() == project_name) else {
            return Err(BeaverError::NoProjectNamed(project_name.to_string()));
        };
        return cb(project);
    }

    pub fn with_project_mut<S>(
        &self,
        project_id: usize,
        cb: impl FnOnce(&mut AnyProject) -> crate::Result<S>
    ) -> crate::Result<S> {
        let mut projects = self.projects_mut()?;
        return cb(&mut projects[project_id]);
    }

    pub fn with_current_project_mut<S>(
        &self,
        cb: impl FnOnce(&mut AnyProject) -> crate::Result<S>
    ) -> crate::Result<S> {
        let Some(idx) = self.current_project_index() else {
            return Err(BeaverError::NoProjects);
        };
        let mut projects = self.projects_mut()?;
        return cb(&mut projects[idx]);
    }

    pub fn with_current_project<S>(
        &self,
        cb: impl FnOnce(&AnyProject) -> crate::Result<S>
    ) -> crate::Result<S> {
        let Some(idx) = self.current_project_index() else {
            return Err(BeaverError::NoProjects);
        };
        let projects = self.projects()?;
        return cb(&projects[idx]);
    }

    pub fn parse_target_ref(&self, dep: &str) -> crate::Result<TargetRef> {
        if dep.contains(":") {
            let mut components = dep.splitn(2, ":");
            let project_name = components.next().unwrap();
            let target_name = components.next().unwrap();

            self.with_project_named(project_name, |project| {
                match project.find_target(target_name) {
                    Err(err) => Err(err),
                    Ok(target_idx) => Ok(TargetRef { project: project.id().unwrap(), target: target_idx.unwrap() })
                }
            })
        } else {
            let idx = match self.current_project_index() {
                None => Err(BeaverError::NoProjects),
                Some(idx) => Ok(idx)
            }?;

            let projects = self.projects()?;
            let project = &projects[idx];

            let Some(target_idx) = project.find_target(dep)? else {
                return Err(BeaverError::NoTargetNamed(dep.to_string(), project.name().to_string()));
            };

            Ok(TargetRef {
                target: target_idx,
                project: idx
            })
        }
    }

    fn build_file(&self) -> crate::Result<PathBuf> {
        self.get_build_dir()
            .map(|path| path.join(format!("build.{}.{}.ninja", self.optimize_mode, self.target_triple)))
    }

    pub fn create_build_file(&self) -> crate::Result<()> {
        let build_dir = self.build_dir.read().map_err(|err| BeaverError::LockError(err.to_string()))?;
        if !build_dir.exists() {
            fs::create_dir(build_dir.as_path())?;
        }
        let ninja_builder: Arc<RwLock<NinjaBuilder>> = Arc::new(RwLock::new(NinjaBuilder::new(&env::current_dir()?, &build_dir)));
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
        let output = builder.build();
        let output_file = self.build_file()?;

        let mut file = fs::File::options()
            .write(true)
            .create(true)
            .open(output_file)
            .map_err(|err| BeaverError::BuildFileWriteError(err))?;
        file.write(output.as_bytes())
            .map_err(|err| BeaverError::BuildFileWriteError(err))?;

        return Ok(());
    }

    /// Retrieve the names to use when calling the backend
    ///
    /// For this implementation we assume we won't be passed a lot of targets. This implementation
    /// is not efficient for high number of targets because there is a lot of locking. If we ever need
    /// something more efficient, see `Iterator::partition_in_place`
    fn qualified_names(&self, targets: &[TargetRef]) -> crate::Result<Vec<String>> {
        let projects = self.projects()?;
        let mut names = Vec::new();
        names.reserve_exact(targets.len());
        for target in targets {
            let project = &projects[target.project];
            let targets = project.targets()?;
            let target = &targets[target.target];
            names.push(format!("{}:{}", project.name(), target.name()))
        }

        return Ok(names);
    }

    pub fn build(&self, target: TargetRef) -> crate::Result<()> {
        self.build_all(&[target])
    }

    pub fn build_all(&self, targets: &[TargetRef]) -> crate::Result<()> {
        let build_file = self.build_file()?;
        let ninja_runner = NinjaRunner::new(&build_file, self.verbose);
        let target_names = self.qualified_names(targets)?;
        let build_dir = self.get_build_dir()?;
        ninja_runner.build(target_names.as_slice(), &env::current_dir()?, &build_dir)
    }

    pub fn build_current_project(&self) -> crate::Result<()> {
        self.with_current_project(|project| {
            match project.targets() {
                Ok(targets) => {
                    self.build_all(targets.iter().map(|target| target.tref().unwrap()).collect::<Vec<TargetRef>>().as_slice())
                },
                Err(err) => Err(err)
            }
        })
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
