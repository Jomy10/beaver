use std::collections::HashMap;
use std::ffi::OsStr;
use std::fmt::Write;
use std::process::Command;
use std::{env, fs, io};
use std::io::Write as IOWrite;
use std::path::{Path, PathBuf};
use std::sync::{Arc, Mutex, MutexGuard, OnceLock, RwLock, RwLockReadGuard, RwLockWriteGuard};
use std::sync::atomic::{AtomicBool, AtomicIsize, AtomicU8, Ordering};

use console::style;
use log::{error, info, trace};
use target_lexicon::Triple;

use crate::backend::ninja::{NinjaBuilder, NinjaRunner};
use crate::backend::BackendBuilder;
use crate::cache::Cache;
use crate::command::Commands;
use crate::traits::{AnyLibrary, AnyProject};
use crate::OptimizationMode;
use crate::phase_hook::{Phase, PhaseHook, PhaseHooks};
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

#[derive(Debug)]
struct BuildDirs {
    /// base_dir/{build_dir}
    base: PathBuf,
    /// base_dir/{build_dir}/{triple}/{optimization_mode}
    output: PathBuf
}

/// All methods of this struct are immutable because this struct ensures all calls to its
/// methods are thread safe
#[derive(Debug)]
pub struct Beaver {
    projects: RwLock<Vec<AnyProject>>,
    project_index: AtomicIsize,
    pub(crate) optimize_mode: OptimizationMode,
    build_dirs: OnceLock<BuildDirs>,
    enable_color: bool,
    pub(crate) target_triple: Triple,
    verbose: bool,
    /// enable various debug utilities. adds -d explain to ninja
    debug: bool,
    cache: OnceLock<Cache>,
    status: AtomicState,
    phase_hook_build: Mutex<PhaseHooks>,
    phase_hook_run: Mutex<PhaseHooks>,
    phase_hook_clean: Mutex<PhaseHooks>,
    commands: Mutex<Commands>,
    /// Indicates wether the symlink to the last built target has been created
    symlink_created: AtomicBool,
    // lock_builddir: AtomicBool,
    // /// Create the build file once and store the result of the operation in this cell
    // build_file_create_result: OnceLock<crate::Result<()>>,
}

impl Beaver {
    pub fn new(enable_color: Option<bool>, optimize_mode: OptimizationMode, verbose: bool, debug: bool) -> crate::Result<Beaver> {
        Ok(Beaver {
            projects: RwLock::new(Vec::new()),
            project_index: AtomicIsize::new(-1),
            optimize_mode,
            build_dirs: OnceLock::new(),
            enable_color: enable_color.unwrap_or(true), // TODO: derive from isatty or set instance var to optional
            target_triple: Triple::host(),
            verbose,
            debug,
            cache: OnceLock::new(),
            status: AtomicState::new(BeaverState::Initialized as u8),
            phase_hook_build: Mutex::new(PhaseHooks(Vec::new())),
            phase_hook_run: Mutex::new(PhaseHooks(Vec::new())),
            phase_hook_clean: Mutex::new(PhaseHooks(Vec::new())),
            commands: Mutex::new(Commands(HashMap::new())),
            symlink_created: AtomicBool::new(false),
            // lock_builddir: AtomicBool::new(false),
            // build_file_create_result: OnceLock::new()
        })
    }

    pub fn color_enabled(&self) -> bool {
        self.enable_color
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

    fn create_build_dirs(&self, dir: impl AsRef<Path>) -> crate::Result<BuildDirs> {
        let base = std::env::current_dir().map_err(BeaverError::from)?.join(dir);
        if !base.exists() {
            fs::create_dir_all(base.as_path()).map_err(BeaverError::from)?;
        }

        let outdir = base.join(&self.target_triple.to_string()).join(&self.optimize_mode.to_string());
        if !outdir.exists() {
            fs::create_dir_all(outdir.as_path()).map_err(BeaverError::from)?;
        }

        Ok(BuildDirs {
            base,
            output: outdir
        })
    }

    /// Initialize if not done yet, otherwise get the value
    fn lock_build_dir(&self) -> crate::Result<&BuildDirs> {
        self.build_dirs.get_or_try_init(|| {
            self.create_build_dirs("build") // default value
        })
    }

    /// Initialize the build dir
    pub fn set_build_dir(&self, dir: PathBuf) -> crate::Result<()> {
        let dirs = self.create_build_dirs(dir)?;

        self.build_dirs.set(dirs).map_err(|_| {
            BeaverError::SetBuildDirAfterAddProject // or build_dir called multiple times
        })
    }

    #[inline]
    pub fn get_build_dir(&self) -> crate::Result<&Path> {
        Ok(&self.lock_build_dir()?.output)
    }

    #[inline]
    pub fn get_base_build_dir(&self) -> crate::Result<&Path> {
        Ok(&self.lock_build_dir()?.base)
    }

    pub fn get_build_dir_for_project(&self, project_name: &str) -> crate::Result<PathBuf> {
        self.get_build_dir().map(|build_dir| build_dir.join(project_name))
    }

    /// Directory for storing intermediate files, etc
    #[inline]
    pub fn get_build_dir_for_external_build_system(&self, base_dir: &Path) -> crate::Result<PathBuf> {
        let Some(base_dir_str) = base_dir.to_str() else {
            return Err(BeaverError::NonUTF8OsStr(base_dir.as_os_str().to_os_string()));
        };
        self.get_build_dir_for_external_build_system2(base_dir_str)
    }

    pub fn get_build_dir_for_external_build_system2(&self, base_dir_str: impl AsRef<str>) -> crate::Result<PathBuf> {
        self.get_build_dir().map(|build_dir| build_dir
            .join("__beaver_external")
            .join(urlencoding::encode(base_dir_str.as_ref())))
    }

    /// Directory for storing intermediate files, etc. This version doesn't change based on target triple or optimization mode
    #[inline]
    pub fn get_build_dir_for_external_build_system_static(&self, base_dir: &Path) -> crate::Result<PathBuf> {
        let Some(base_dir_str) = base_dir.to_str() else {
            return Err(BeaverError::NonUTF8OsStr(base_dir.as_os_str().to_os_string()));
        };
        self.get_build_dir_for_external_build_system_static2(base_dir_str)
    }

    pub fn get_build_dir_for_external_build_system_static2(&self, base_dir_str: impl AsRef<str>) -> crate::Result<PathBuf> {
        self.get_base_build_dir().map(|build_dir| build_dir
            .join("__beaver_external")
            .join(urlencoding::encode(base_dir_str.as_ref())))
    }

    fn create_symlink(&self) -> crate::Result<()> {
        let Ok(_) = self.symlink_created.compare_exchange(false, true, Ordering::Relaxed, Ordering::Relaxed) else {
            return Ok(()); // when error, then this function has already been executed
        };

        // let from = self.get_build_dir()?;
        let from: PathBuf = self.with_current_project(|proj| {
            match proj {
                AnyProject::Beaver(project) => Ok(project.build_dir().join("artifacts")),
                _ => self.get_build_dir().map(|path| path.to_path_buf())
            }
        })?;
        let to = self.get_base_build_dir()?.join(self.optimize_mode.to_string());

        if to.exists() {
            if to.is_symlink() {
                fs::remove_file(&to)?;
            } else {
                return Err(BeaverError::SymlinkCreationExists(to));
            }
        }

        let mut create_symlink = true;
        match fs::read_link(&to) {
            Ok(links_to) => if links_to != from {
                fs::remove_file(&to)?;
            } else {
                create_symlink = false;
            },
            Err(err) => match err.kind() {
                io::ErrorKind::NotFound => {}
                _ => {
                    dbg!(err.kind());
                    return Err(BeaverError::SymlinkCreationError(err, from, to));
                }
            },
        }

        if create_symlink {
            utils::fs::symlink_dir(&from, &to)
                .map_err(|err| { dbg!(err.kind()); BeaverError::SymlinkCreationError(err, from.to_path_buf(), to) })
        } else {
            Ok(())
        }
    }

    pub fn cache(&self) -> Result<&Cache, BeaverError> {
        self.cache.get_or_try_init(|| { // TODO: on base build dir
            let build_dir = self.get_base_build_dir()?;
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
    // TODO: build/triple/optimize mode & symlink current triple

    fn build_file(&self) -> crate::Result<PathBuf> {
        self.get_build_dir()
            .map(|path| path.join("build.ninja"))
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

        self.run_phase_hook(Phase::Build)?;

        let build_file = self.build_file()?;
        let ninja_runner = NinjaRunner::new(&build_file, self.verbose, self.debug);
        let build_dir = self.get_build_dir()?;
        ninja_runner.build(target_names, &env::current_dir()?, &build_dir)?;

        self.create_symlink()?;

        Ok(())
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

        self.run_phase_hook(Phase::Run)?;

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

    pub fn clean(&self) -> crate::Result<()> {
        info!("Cleaning all projects...");

        if self.projects()?.len() == 0 {
            info!("Nothing to clean (no projects defined)");
            return Ok(());
        }

        self.run_phase_hook(Phase::Clean)?;

        for project in self.projects()?.iter() {
            project.clean(self)?;
        }

        fs::remove_dir_all(self.get_build_dir()?)?;

        Ok(())
    }

    /// Adding a phase hook or "pre-phase hook" is a function that will run before the user
    /// requests the given phase. e.g. when a user requests a build, then the functions stored in
    /// the build hooks will be ran first
    pub fn add_phase_hook(&self, phase: Phase, hook: PhaseHook) -> crate::Result<()> {
        if self.status.load(Ordering::SeqCst) != BeaverState::Initialized as u8 {
            return Err(BeaverError::AlreadyFinalized);
        }
        // let mut hooks = self.phase_hooks.lock().map_err(|err| BeaverError::LockError(err.to_string()))?;
        match phase {
            Phase::Build => self.phase_hook_build.lock()
                .map_err(|err| BeaverError::LockError(err.to_string()))?
                .0.push(hook),
            Phase::Run => self.phase_hook_run.lock()
                .map_err(|err| BeaverError::LockError(err.to_string()))?
                .0.push(hook),
            Phase::Clean => self.phase_hook_clean.lock()
                .map_err(|err| BeaverError::LockError(err.to_string()))?
                .0.push(hook),
        }
        Ok(())
    }

    fn get_hook_ignore_block(hooks: &Mutex<PhaseHooks>) -> crate::Result<Option<MutexGuard<'_, PhaseHooks>>> {
        match hooks.try_lock() {
            Ok(val) => Ok(Some(val)),
            Err(err) => match err {
                std::sync::TryLockError::Poisoned(poison_error) => Err(BeaverError::LockError(poison_error.to_string())),
                std::sync::TryLockError::WouldBlock => Ok(None),
            },
        }
    }

    /// Run all the registered hooks for a particular phase. When this function is called multiple times for the
    /// same phase, the hooks will only run on the first invocation
    fn run_phase_hook(&self, phase: Phase) -> crate::Result<()> {
        match BeaverState::try_from(self.status.load(Ordering::SeqCst))? {
            BeaverState::Initialized => self.create_build_file()?, // finalize beaver
            BeaverState::Invalid => return Err(BeaverError::UnrecoverableError),
            BeaverState::Build => {},
        }

        let hooks = match phase {
            // We can ignore would block because we have checked that the state is Build
            // This means no new hooks will be added and if the mutex is locked, we are
            // already draining the hooks. This function is being called from inside of
            // a hook
            Phase::Build => Self::get_hook_ignore_block(&self.phase_hook_build),
            Phase::Run => Self::get_hook_ignore_block(&self.phase_hook_run),
            Phase::Clean => Self::get_hook_ignore_block(&self.phase_hook_clean),
        }?;

        let mut hooks = match hooks {
            Some(hooks) => hooks,
            None => {
                trace!("Ignoring phase hook {:?}", phase);
                return Ok(());
            }
        };

        hooks.0.drain(0..)
            .map(|fun| fun())
            .collect::<Result<(), Box<dyn std::error::Error>>>()
            .map_err(|err| BeaverError::AnyError(err.to_string()))
    }

    pub fn add_command(&self, name: String, command: crate::command::Command) -> crate::Result<()> {
        if self.status.load(Ordering::SeqCst) != BeaverState::Initialized as u8 {
            return Err(BeaverError::AlreadyFinalized);
        }
        let mut guard = self.commands.lock().map_err(|err| BeaverError::LockError(err.to_string()))?;
        if guard.0.contains_key(&name) {
            return Err(BeaverError::CommandExists(name.to_string()));
        }
        _ = guard.0.insert(name, command);

        Ok(())
    }

    pub fn run_command(&self, name: &str) -> crate::Result<()> {
        match BeaverState::try_from(self.status.load(Ordering::SeqCst))? {
            BeaverState::Initialized => self.create_build_file()?, // finalize beaver
            BeaverState::Invalid => return Err(BeaverError::UnrecoverableError),
            BeaverState::Build => {},
        }
        let mut guard = self.commands.lock().map_err(|err| BeaverError::LockError(err.to_string()))?;

        let Some(command) = guard.0.remove(name) else {
            return Err(BeaverError::NoCommand(name.to_string()));
        };
        command().map_err(|err| BeaverError::AnyError(err.to_string()))
    }

    pub fn has_command(&self, name: &str) -> crate::Result<bool> {
        let guard = self.commands.lock().map_err(|err| BeaverError::LockError(err.to_string()))?;

        return Ok(guard.0.contains_key(name));
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
