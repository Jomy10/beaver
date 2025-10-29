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
use log::*;
use program_communicator::socket::ReceiveResult;
use target_lexicon::Triple;
use zerocopy::IntoBytes;

use crate::backend::ninja::{NinjaBuilder, NinjaRunner};
use crate::backend::BackendBuilder;
use crate::cache::Cache;
use crate::command::Commands;
use crate::traits::{AnyExecutable, AnyLibrary, AnyProject};
use crate::{tools, OptimizationMode};
use crate::phase_hook::{Phase, PhaseHook, PhaseHooks};
use crate::error::BeaverError;
use crate::project::traits::Project;
use crate::target::traits::{AnyTarget, Target};
use crate::target::{ArtifactType, Dependency, ExecutableArtifactType, TargetRef};
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

pub(crate) struct CommunicationSocket(pub(crate) OnceLock<program_communicator::socket::Socket>);

impl std::fmt::Debug for CommunicationSocket {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str("CommunicationSocket")
    }
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

    pub(crate) comm_socket: CommunicationSocket,
}

impl Beaver {
    pub fn new(
        enable_color: Option<bool>,
        optimize_mode: OptimizationMode,
        verbose: bool, debug: bool,
        target: Triple
    ) -> crate::Result<Beaver> {
        if target != Triple::host() {
            warn!("Cross-compilation is in early development, expect bugs");
        }

        tools::set_target_triple(target.clone());

        Ok(Beaver {
            projects: RwLock::new(Vec::new()),
            project_index: AtomicIsize::new(-1),
            optimize_mode,
            build_dirs: OnceLock::new(),
            enable_color: enable_color.unwrap_or(true), // TODO: derive from isatty or set instance var to optional
            target_triple: target,
            verbose,
            debug,
            cache: OnceLock::new(),
            status: AtomicState::new(BeaverState::Initialized as u8),
            phase_hook_build: Mutex::new(PhaseHooks(Vec::new())),
            phase_hook_run: Mutex::new(PhaseHooks(Vec::new())),
            phase_hook_clean: Mutex::new(PhaseHooks(Vec::new())),
            commands: Mutex::new(Commands(HashMap::new())),
            symlink_created: AtomicBool::new(false),
            comm_socket: CommunicationSocket(OnceLock::new())
            // lock_builddir: AtomicBool::new(false),
            // build_file_create_result: OnceLock::new()
        })
    }

    /// Get the target triple we are compiling for
    pub fn target_triple(&self) -> &Triple {
        &self.target_triple
    }

    pub fn opt_mode(&self) -> &OptimizationMode {
        &self.optimize_mode
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
                    trace!("(err kind) {}", err.kind());
                    return Err(BeaverError::SymlinkCreationError(err, from, to));
                }
            },
        }

        if create_symlink {
            utils::fs::symlink_dir(&from, &to)
                .map_err(|err| { trace!("(err kind) {}", err.kind()); BeaverError::SymlinkCreationError(err, from.to_path_buf(), to) })
        } else {
            Ok(())
        }
    }

    pub fn cache(&self) -> Result<&Cache, BeaverError> {
        self.cache.get_or_try_init(|| {
            trace!("Getting build dir");
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
        if let Some(proj) = projects.iter().find(|proj| proj.name() == project.name()) {
            return Err(BeaverError::ProjectAlreadyExists(project.name().to_string(), proj.id().unwrap()));
        }
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

    pub fn with_project_and_target<S, E: From<BeaverError>>(
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

    pub fn with_project_and_target_mut<S, E: From<BeaverError>>(
        &self,
        target: &TargetRef,
        cb: impl FnOnce(&AnyProject, &mut AnyTarget) -> Result<S, E>
    ) -> Result<S, E> {
        let mut projects = self.projects_mut()?;

        let project_mut = projects.get_mut(target.project).expect("Invalid TargetRef"); // We assume a TargetRef is always acquired from a target that exists
        // We obtain a pointer, because we know we will only mutate one of its targets, not any of its other traits
        // We can then safely pass this as a reference to the callback, because they're scoped to this function
        let project_ptr: *const AnyProject = &*project_mut;
        match project_mut {
            AnyProject::Beaver(project) => {
                cb(unsafe { &*project_ptr }, project.targets_mut()?
                    .get_mut(target.target)
                    .expect("Invalid TargetRef"))
            },
            AnyProject::CMake(project) => Err(BeaverError::ProjectNotTargetMutable(project.name().to_string()).into()),
            AnyProject::Cargo(project) => Err(BeaverError::ProjectNotTargetMutable(project.name().to_string()).into()),
            AnyProject::SPM(project) => Err(BeaverError::ProjectNotTargetMutable(project.name().to_string()).into()),
            AnyProject::Meson(project) => {
                cb(unsafe { &*project_ptr }, project.targets_mut()
                    .get_mut(target.target)
                    .expect("Invalid TargetRef"))
            }
        }
    }

    /// Access a CMakeProject and a library with the given `cmake_id`
    pub fn with_cmake_project_and_library<S>(
        &self,
        cmake_id: &str,
        // The argument is optional because a CMake target may be unmapped
        cb: impl FnOnce(&CMakeProject, Option<&CMakeLibrary>) -> crate::Result<S>
    ) -> crate::Result<S> {
        use itertools::Itertools;

        let projects = self.projects()?;
        for project in projects.iter() {
            match project {
                AnyProject::CMake(project) => {
                    let targets = project.targets()?;
                    for target in targets.iter() {
                        match target {
                            AnyTarget::Library(lib) => match lib {
                                AnyLibrary::CMake(lib) => if lib.cmake_id() == cmake_id {
                                    return cb(&project, Some(&lib));
                                },
                                _ => continue,
                            },
                            _ => continue,
                        }
                    }
                    if project.unmapped_cmake_ids.iter().map(|str| str.as_str()).contains(cmake_id) {
                        return cb(&project, None);
                    }
                },
                _ => continue,
            }
        }

        debug!("CMake ID not found {}\nin projects: {:#?}", cmake_id, projects);
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

    pub fn with_project<S>(
        &self,
        project_id: usize,
        cb: impl FnOnce(&AnyProject) -> crate::Result<S>
    ) -> crate::Result<S> {
        let projects = self.projects()?;
        return cb(&projects[project_id]);
    }

    pub fn with_current_project_mut<S, E: From<BeaverError>>(
        &self,
        cb: impl FnOnce(&mut AnyProject) -> Result<S, E>
    ) -> Result<S, E> {
        if self.status.load(Ordering::SeqCst) != BeaverState::Initialized as u8 {
            return Err(BeaverError::AlreadyFinalized.into());
        }
        let Some(idx) = self.current_project_index() else {
            return Err(BeaverError::NoProjects.into());
        };
        let mut projects = self.projects_mut()?;
        return cb(&mut projects[idx]);
    }

    pub fn with_current_project<S, E: From<BeaverError>>(
        &self,
        cb: impl FnOnce(&AnyProject) -> Result<S, E>
    ) -> Result<S, E> {
        let Some(idx) = self.current_project_index() else {
            return Err(BeaverError::NoProjects.into());
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
                        Ok(target_idx) => Ok(TargetRef { project: project.id().unwrap(), target: target_idx.expect("Target doesn't exist") })
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

    /// If `callback_path` is set, this indicates that a message should be sent to the caller of the command
    fn handle_communication(self: &Arc<Self>, reader: &mut dyn io::Read, callback_path: &mut Option<PathBuf>) -> crate::Result<ReceiveResult> {
        trace!(target: "communication", "Received message to communication socket");

        let mut str = String::new();
        reader.read_to_string(&mut str)?;

        let i = str.chars().position(|c| c == ' ').unwrap_or(str.len());
        let cmd = &str[..i];

        match cmd {
            "close" => Ok(ReceiveResult::Close),
            "build" => {
                #[cfg(unix)] {
                    trace!(target: "communication", "message is a build message");
                    let target_end = i+1 + str[i+1..].chars().position(|c| c == ' ').expect("invalid formatted command");
                    let mut target = str[i+1..target_end].split(":");
                    let project_id = target.next().unwrap().parse::<usize>().unwrap();
                    let target_id = target.next().unwrap().parse::<usize>().unwrap();
                    assert!(target.next().is_none());

                    *callback_path = Some(PathBuf::from(&str[target_end+1..].trim()));

                    trace!(target: "communication", "parameters: project_id={} target_id={} callback_path={:?}", project_id, target_id, callback_path);

                    self.with_project(project_id, |proj| {
                        let target = &proj.targets()?[target_id];
                        trace!("{:?}", target);

                        match target {
                            AnyTarget::Library(lib) => match lib {
                                AnyLibrary::Custom(library) => library.build()?,
                                _ => return Err(BeaverError::TargetHasNoBuildCommand(target.name().to_string()))
                            },
                            AnyTarget::Executable(exe) => match exe {
                                AnyExecutable::Custom(executable) => executable.build()?,
                                _ => return Err(BeaverError::TargetHasNoBuildCommand(target.name().to_string()))
                            },
                        }

                        Ok(())
                    })?;

                    Ok(ReceiveResult::Continue)
                }

                #[cfg(not(unix))] {
                    panic!("Custom targets are not supported on this platform");
                }

                // // let target_ref = unsafe { &(**self_ptr.value()) }.parse_target_ref(target).map_err(|err| Box::new(err) as Box<dyn std::error::Error + Send>)?;
                // match self2.build(target_ref) {
                //     Ok(()) => {
                //         #[cfg(unix)] {
                //             program_communicator::callback::unix::send_message(&callback_path, '0'.as_bytes()).map_err(|err| Box::new(err) as Box<dyn std::error::Error + Send>)?;
                //         }
                //         #[cfg(not(unix))] {
                //             panic!("Custom targets not supported on this platform");
                //         }
                //     },
                //     Err(err) => {
                //         error!("{err}");
                //         #[cfg(unix)] {
                //             program_communicator::callback::unix::send_message(&callback_path, '1'.as_bytes()).map_err(|err| Box::new(err) as Box<dyn std::error::Error + Send>)?;
                //         }
                //         #[cfg(not(unix))] {
                //             panic!("Custom targets not supported on this platform");
                //         }
                //     },
                // }

            },
            _ => {
                error!("Invalid command {cmd}");
                Ok(ReceiveResult::Continue)
            }
        }
    }

    pub(crate) fn enable_communication(self: &Arc<Self>) -> crate::Result<()> {
        let self2 = Arc::downgrade(self);
        let _ = self.comm_socket.0.set(program_communicator::socket::listen("beaver_custom_targets", move |reader| {
            let mut callback_path: Option<PathBuf> = None;
            let Some(self2) = self2.upgrade() else {
                return Ok(ReceiveResult::Close);
            };
            match self2.handle_communication(reader, &mut callback_path) {
                Ok(res) => {
                    trace!(target: "communication", "message result = {:?}", res);
                    #[cfg(unix)] {
                        if let Some(callback_path) = callback_path {
                            program_communicator::callback::unix::send_message(&callback_path, '0'.as_bytes())
                                .map_err(|err| Box::new(err) as Box<dyn std::error::Error + Send>)?;
                        }
                    }
                    Ok(res)
                },
                Err(err) => {
                    error!(target: "communication", "{}", err);
                    #[cfg(unix)] {
                        if let Some(callback_path) = callback_path {
                            program_communicator::callback::unix::send_message(&callback_path, '1'.as_bytes())
                                .map_err(|err| Box::new(err) as Box<dyn std::error::Error + Send>)?;
                        }
                    }
                    Err(Box::new(err) as Box<dyn std::error::Error + Send>)
                },
            }
        }).map_err(|err| BeaverError::AnyError(err.to_string()))?);

        Ok(())
    }

    pub fn create_build_file(self: &Arc<Self>) -> crate::Result<()> {
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

    pub fn build(self: &Arc<Self>, target: TargetRef) -> crate::Result<()> {
        self.build_all(&[target])
    }

    pub fn build_all(self: &Arc<Self>, targets: &[TargetRef]) -> crate::Result<()> {
        let target_names = self.qualified_names(targets)?;
        let target_names: Vec<&str> = target_names.iter().map(|str| str.as_str()).collect();
        self.build_all_named(target_names.as_slice())
    }

    pub fn build_all_named(self: &Arc<Self>, target_names: &[&str]) -> crate::Result<()> {
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

    pub fn build_current_project(self: &Arc<Self>) -> crate::Result<()> {
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

    pub fn run<I: IntoIterator<Item = S>, S: AsRef<OsStr>>(self: &Arc<Self>, target: TargetRef, args: I) -> crate::Result<()> {
        if self.target_triple != Triple::host() {
            panic!("Running targets in a triple that is not the current host is currently unsupported");
        }
        self.build(target)?;

        self.run_phase_hook(Phase::Run)?;

        let artifact_file = self.with_project_and_target::<PathBuf, BeaverError>(&target, |project, target| {
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

    pub fn run_default<I: IntoIterator<Item = S>, S: AsRef<OsStr>>(self: &Arc<Self>, args: I) -> crate::Result<()> {
        let exe = self.with_current_project(|project| {
            project.default_executable()
        })?;
        self.run(exe, args)
    }

    pub fn clean(self: &Arc<Self>) -> crate::Result<()> {
        info!("Cleaning all projects...");

        self.cache()?.reset()?;

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
    fn run_phase_hook(self: &Arc<Self>, phase: Phase) -> crate::Result<()> {
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

    pub fn run_command(self: &Arc<Self>, name: &str) -> crate::Result<()> {
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
                for dependency in target.dependencies()?.as_ref() {
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

#[derive(Default)]
pub struct PrintOptions {
    pub artifacts: bool,
    pub dependencies: bool
}

impl Beaver {
    pub fn print(&self, f: &mut std::fmt::Formatter<'_>, options: PrintOptions) -> std::fmt::Result {
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
                if options.artifacts {
                    f.write_fmt(format_args!(" ({})", target.artifacts().iter().map(|artifact| match artifact {
                        ArtifactType::Library(library_artifact_type) => library_artifact_type.to_string(),
                        ArtifactType::Executable(executable_artifact_type) => executable_artifact_type.to_string(),
                    }).collect::<Vec<_>>().join(", ")))?;
                }
                f.write_str("\n")?;
                if options.dependencies {
                    match target.dependencies() {
                        Ok(dependencies) => {
                            if dependencies.len() > 0 {
                                f.write_str("    Dependencies:\n")?;
                                for dependency in dependencies.iter() {
                                    self.print_fmt_dependency(f, dependency, &options)?;
                                }
                            }
                        },
                        Err(err) => f.write_fmt(format_args!("    Couldn't fetch dependencies: {}", err))?
                    }
                }
            }
        }

        Ok(())
    }

    fn print_fmt_dependency(&self, f: &mut std::fmt::Formatter<'_>, dependency: &Dependency, options: &PrintOptions) -> std::fmt::Result {
        match dependency {
            Dependency::Library(library_target_dependency) => {
                let target_name = self.with_project_and_target::<String, BeaverError>(&library_target_dependency.target, |_, target| {
                    Ok(target.name().to_string())
                }).unwrap();
                f.write_fmt(format_args!("      - {}", target_name))?;
                if options.artifacts {
                    f.write_fmt(format_args!(" ({})", library_target_dependency.artifact))?;
                }
                f.write_char('\n')?;
            },
            Dependency::Flags { cflags, linker_flags } => {
                f.write_fmt(format_args!("      - {{ cflags: {}, lflags: {} }}\n", cflags.clone().unwrap_or(vec![]).join(", "), linker_flags.clone().unwrap_or(vec![]).join(", ")))?;
            },
            Dependency::CMakeId(id) => {
                let target_name = self.with_cmake_project_and_library(id, |_, target| {
                    Ok(target.unwrap().name().to_string())
                }).unwrap();
                f.write_fmt(format_args!("      - {}\n", target_name))?;
            },
            Dependency::Multi(items) => {
                for item in items {
                    self.print_fmt_dependency(f, item, options)?;
                }
            },
            Dependency::File(file) => {
                f.write_fmt(format_args!("      - {:?}\n", file))?;
            }
        }

        Ok(())
    }

}

impl std::fmt::Display for Beaver {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        self.print(f, PrintOptions::default())
    }
}

impl Drop for Beaver {
    fn drop(&mut self) {
        if self.comm_socket.0.get().is_some() {
            if let Some(socket) = self.comm_socket.0.take() {
                socket.send("close").unwrap();
                #[cfg(unix)] {
                    use program_communicator::socket::SocketUnixExt;
                    socket.wait().unwrap();
                }
            }
        }
    }
}
