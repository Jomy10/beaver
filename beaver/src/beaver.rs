use std::ffi::OsStr;
use std::fmt::Write;
use std::process::Command;
use std::{env, fs, path};
use std::io::Write as IOWrite;
use std::path::PathBuf;
use std::sync::{Arc, OnceLock, RwLock, RwLockReadGuard, RwLockWriteGuard};
use std::sync::atomic::{AtomicIsize, AtomicU8, Ordering};

use console::style;
use log::{error, trace};
use target_lexicon::Triple;

use crate::backend::ninja::{NinjaBuilder, NinjaRunner};
use crate::backend::BackendBuilder;
use crate::cache::Cache;
use crate::traits::{AnyLibrary, AnyProject};
use crate::OptimizationMode;
use crate::error::BeaverError;
use crate::project::traits::Project;
use crate::target::traits::{AnyTarget, Target};
use crate::target::{ArtifactType, ExecutableArtifactType, TargetRef};
use crate::target::cmake::Library as CMakeLibrary;
use crate::project::cmake::Project as CMakeProject;

#[derive(PartialEq, Eq, Debug)]
#[repr(u8)]
enum BeaverState {
    /// Beaver has been initialized and projects can be added to it
    Initialized = 0,
    /// An unrecoverable error occurred
    Invalid     = 1,
    /// Beaver is ready to start building
    Build       = 2,
}

impl TryFrom<u8> for BeaverState {
    type Error = BeaverError;

    fn try_from(value: u8) -> Result<Self, Self::Error> {
        match value {
            0 => Ok(BeaverState::Initialized),
            1 => Ok(BeaverState::Invalid),
            2 => Ok(BeaverState::Build),
            _ => Err(BeaverError::InvalidState(value)),
        }
    }
}

type AtomicState = AtomicU8;

/// All methods of this struct are immutable because this struct ensures all calls to its
/// methods are thread safe
#[derive(Debug)]
pub struct Beaver {
    projects: RwLock<Vec<AnyProject>>,
    project_index: AtomicIsize,
    pub(crate) optimize_mode: OptimizationMode,
    build_dir: OnceLock<PathBuf>,
    enable_color: bool,
    target_triple: Triple,
    verbose: bool,
    cache: OnceLock<Cache>,
    status: AtomicState,
    // lock_builddir: AtomicBool,
    // /// Create the build file once and store the result of the operation in this cell
    // build_file_create_result: OnceLock<crate::Result<()>>,
}

impl Beaver {
    pub fn new(enable_color: Option<bool>, optimize_mode: OptimizationMode) -> crate::Result<Beaver> {
        Ok(Beaver {
            projects: RwLock::new(Vec::new()),
            project_index: AtomicIsize::new(-1),
            optimize_mode,
            build_dir: OnceLock::new(), //OnceLock::new(path::absolute(std::env::current_dir().unwrap().join("build"))?),
            enable_color: enable_color.unwrap_or(true), // TODO: derive from isatty or set instance var to optional
            target_triple: Triple::host(),
            verbose: false,
            cache: OnceLock::new(),
            status: AtomicState::new(BeaverState::Initialized as u8),
            // lock_builddir: AtomicBool::new(false),
            // build_file_create_result: OnceLock::new()
        })
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

    pub fn lock_build_dir(&self) -> crate::Result<&PathBuf> {
        let res: Result<&PathBuf, BeaverError> = self.build_dir.get_or_try_init(|| {
            let dir = std::env::current_dir().map_err(BeaverError::from)?.join("build");
            if !dir.exists() {
                fs::create_dir(dir.as_path()).map_err(BeaverError::from)?;
            }
            Ok(dir)
        });

        return res;
    }

    pub fn set_build_dir(&self, dir: PathBuf) -> crate::Result<()> {
        self.build_dir.set(path::absolute(dir)?).map_err(|_| {
            BeaverError::SetBuildDirAfterAddProject // or build_dir called multiple times
        })
        // if self.lock_builddir.load(Ordering::SeqCst) {
        // // if self.current_project_index() != None {
        //     return Err(BeaverError::SetBuildDirAfterAddProject);
        // }

        // *self.build_dir.write().map_err(|err| BeaverError::LockError(err.to_string()))? = path::absolute(dir)?;
        // Not needed because of check
        // for project in self.projects_mut()?.iter_mut() {
        //     project.update_build_dir(&self.build_dir);
        // }
        // return Ok(());
    }

    pub fn get_build_dir(&self) -> crate::Result<&PathBuf> {
        self.lock_build_dir()
        // self.lock_build_dir()?;
        // self.build_dir.read().map_err(|err| BeaverError::LockError(err.to_string()))
    }

    pub fn cache(&self) -> Result<&Cache, BeaverError> {
        self.cache.get_or_try_init(|| {
            let build_dir = self.get_build_dir()?;
            Cache::new(&build_dir.join("cache"))
        })
    }

    pub fn projects(&self) -> crate::Result<RwLockReadGuard<'_, Vec<AnyProject>>> {
        self.projects.read().map_err(|err| {
            BeaverError::ProjectsReadError(err.to_string())
        })
    }

    fn projects_mut(&self) -> crate::Result<RwLockWriteGuard<'_, Vec<AnyProject>>> {
        if self.status.load(Ordering::SeqCst) != BeaverState::Initialized as u8 {
            return Err(BeaverError::AlreadyFinalized);
        }
        self.projects.write().map_err(|err| {
            BeaverError::ProjectsWriteError(err.to_string())
        })
    }

    pub fn add_project(&self, project: impl Into<AnyProject>) -> crate::Result<usize> {
        if self.status.load(Ordering::SeqCst) != BeaverState::Initialized as u8 {
            return Err(BeaverError::AlreadyFinalized);
        }
        _ = self.lock_build_dir()?;
        let mut project: AnyProject = project.into();
        trace!("Adding project {}", project.name());
        let mut projects = self.projects_mut()?;
        let idx = projects.len();
        project.set_id(idx)?;
        projects.push(project);
        drop(projects);
        self.set_current_project_index(idx);
        return Ok(idx);
    }

    pub fn find_project(&self, name: &str) -> crate::Result<Option<usize>> {
        Ok(self.projects()?.iter().find(|project| project.name() == name).map(|project| project.id().unwrap()))
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

    /// Access a CMakeProject and a library with the given `cmake_id`
    pub fn with_cmake_project_and_library<S>(
        &self,
        cmake_id: &str,
        cb: impl FnOnce(&CMakeProject, &CMakeLibrary) -> crate::Result<S>
    ) -> crate::Result<S> {
        let projects = self.projects()?;
        for project in projects.iter() {
            match project {
                AnyProject::CMake(project) => {
                    let targets = project.targets()?;
                    for target in targets.iter() {
                        match target {
                            AnyTarget::Library(lib) => match lib {
                                AnyLibrary::CMake(lib) => if lib.cmake_id() == cmake_id {
                                    return cb(&project, &lib);
                                },
                                _ => continue,
                            },
                            _ => continue,
                        }
                    }
                },
                _ => continue,
            }
        }

        return Err(BeaverError::NoCMakeTarget(cmake_id.to_string()));
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
        if self.status.load(Ordering::SeqCst) != BeaverState::Initialized as u8 {
            return Err(BeaverError::AlreadyFinalized);
        }
        let mut projects = self.projects_mut()?;
        return cb(&mut projects[project_id]);
    }

    pub fn with_current_project_mut<S>(
        &self,
        cb: impl FnOnce(&mut AnyProject) -> crate::Result<S>
    ) -> crate::Result<S> {
        if self.status.load(Ordering::SeqCst) != BeaverState::Initialized as u8 {
            return Err(BeaverError::AlreadyFinalized);
        }
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
            if dep.starts_with(":") {
                todo!("Allow :{{project_name}} syntax for building a whole project");
            } else {
                let mut components = dep.splitn(2, ":");
                let project_name = components.next().unwrap();
                let target_name = components.next().unwrap();

                self.with_project_named(project_name, |project| {
                    match project.find_target(target_name) {
                        Err(err) => Err(err),
                        Ok(target_idx) => Ok(TargetRef { project: project.id().unwrap(), target: target_idx.unwrap() })
                    }
                })
            }
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
        // TODO: build/triple/optimize mode & symlink current triple
        self.get_build_dir()
            .map(|path| path.join(format!("build.{}.{}.ninja", self.optimize_mode, self.target_triple)))
    }

    pub fn create_build_file(&self) -> crate::Result<()> {
        if self.status.load(Ordering::SeqCst) != BeaverState::Initialized as u8 {
            return Err(BeaverError::AlreadyFinalized);
        }
        self.status.store(BeaverState::Build as u8, Ordering::SeqCst);

        let build_dir = self.get_build_dir()?;
        let ninja_builder: Arc<RwLock<NinjaBuilder>> = Arc::new(RwLock::new(NinjaBuilder::new(&env::current_dir()?, &build_dir))); // TODO: Mutex
        let mut error: OnceLock<BeaverError> = OnceLock::new();
        let projects = self.projects()?;
        rayon::scope(|s| {
            for project in projects.iter() {
                trace!("registering {:?}", project.name());
                s.spawn(|s| match project.register(s, &self.target_triple, ninja_builder.clone(), &self) {
                    Err(err) => {
                        match error.set(err) {
                            Ok(_) => {},
                            Err(err) => error!("{:?}", err)
                        }
                    },
                    Ok(()) => {}
                });
                if error.get().is_some() {
                    break;
                }
            }
        });

        if let Some(err) = error.take() {
            return Err(err);
        }

        let builder = Arc::try_unwrap(ninja_builder).unwrap_or_else(|_| panic!("Arc shouldn't be referenced anymore"));
        let builder = builder.into_inner().map_err(|err| BeaverError::BackendLockError(err.to_string()))?;
        let output = builder.build();
        let output_file = self.build_file()?;

        let mut file = fs::File::options()
            .write(true)
            .create(true)
            .truncate(true)
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
        let target_names = self.qualified_names(targets)?;
        let target_names: Vec<&str> = target_names.iter().map(|str| str.as_str()).collect();
        self.build_all_named(target_names.as_slice())
    }

    pub fn build_all_named(&self, target_names: &[&str]) -> crate::Result<()> {
        match BeaverState::try_from(self.status.load(Ordering::SeqCst))? {
            BeaverState::Initialized => self.create_build_file()?,
            BeaverState::Invalid => return Err(BeaverError::UnrecoverableError),
            BeaverState::Build => {},
        }

        let build_file = self.build_file()?;
        let ninja_runner = NinjaRunner::new(&build_file, self.verbose);
        let build_dir = self.get_build_dir()?;
        ninja_runner.build(target_names, &env::current_dir()?, &build_dir)
    }

    pub fn build_current_project(&self) -> crate::Result<()> {
        self.with_current_project(|project| {
            self.build_all_named(&[project.name()])
            // match project.targets() {
            //     Ok(targets) => {
            //         self.build_all(targets.iter().map(|target| target.tref().unwrap()).collect::<Vec<TargetRef>>().as_slice())
            //     },
            //     Err(err) => Err(err)
            // }
        })
    }

    pub fn run<I: IntoIterator<Item = S>, S: AsRef<OsStr>>(&self, target: TargetRef, args: I) -> crate::Result<()> {
        if self.target_triple != Triple::host() {
            panic!("Running targets in a triple that is not the current host is currently unsupported");
        }
        self.build(target)?;
        let artifact_file = self.with_project_and_target(&target, |project, target| {
            let artifact_type = ArtifactType::Executable(ExecutableArtifactType::Executable);
            if !target.artifacts().contains(&artifact_type) {
                return Err(BeaverError::NoExecutableArtifact(target.name().to_string()));
            }
            target.artifact_file(project.build_dir(), artifact_type, &self.target_triple)
        })?;

        assert!(artifact_file.exists()); // should always be the case, otherwise it's a bug

        let mut process = Command::new(artifact_file.as_path())
            .args(args)
            .current_dir(env::current_dir()?)
            .spawn()?;

        let exit_status = process.wait()?;
        if !exit_status.success() {
            return Err(BeaverError::NonZeroExitStatus(exit_status));
        } else {
            return Ok(());
        }
    }

    pub fn run_default<I: IntoIterator<Item = S>, S: AsRef<OsStr>>(&self, args: I) -> crate::Result<()> {
        let exe = self.with_current_project(|project| {
            project.default_executable()
        })?;
        self.run(exe, args)
    }

    /// Used by the CLI
    pub fn fmt_debug(&self, str: &mut String) -> crate::Result<()> {
        let current_project_index = self.current_project_index();
        for (i, project) in self.projects()?.iter().enumerate() {
            if current_project_index == Some(i) {
                str.write_fmt(format_args!("{}\n", console::style(project.name()).blue())).map_err(|err| BeaverError::DebugBufferWriteError(err))?;
            } else {
                str.write_str(project.name()).map_err(|err| BeaverError::DebugBufferWriteError(err))?;
                str.write_char('\n').map_err(|err| BeaverError::DebugBufferWriteError(err))?;
            }

            for target in project.targets()?.iter() {
                str.write_fmt(format_args!("  {} ({:?}) [{}]\n",
                    target.name(),
                    target.language(),
                    target.artifacts().iter().map(|art| match art {
                        ArtifactType::Library(lib) => lib.to_string(),
                        ArtifactType::Executable(exe) => exe.to_string(),
                    }).intersperse(String::from(", "))
                    .fold(String::new(), |acc, val| {
                        let mut acc = acc;
                        acc.push_str(val.as_str());
                        acc
                    })
                )).map_err(|err| BeaverError::DebugBufferWriteError(err))?;
                for attr in target.debug_attributes() {
                    str.write_fmt(format_args!("    {}: {}\n", attr.0, attr.1)).map_err(|err| BeaverError::DebugBufferWriteError(err))?;
                }
                for dependency in target.dependencies() {
                    if let Some(name) = dependency.ninja_name_not_escaped(self)? {
                        str.write_fmt(format_args!("    -> {}\n", name)).map_err(|err| BeaverError::DebugBufferWriteError(err))?;
                    } else {
                        str.write_fmt(format_args!("    -> {:?}\n", dependency)).map_err(|err| BeaverError::DebugBufferWriteError(err))?;
                    }
                }
            }
        }

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
