use std::ffi::OsString;
use std::hash::{DefaultHasher, Hash, Hasher};
use std::io::Read;
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};
use std::sync::OnceLock;

use log::*;
use target_lexicon::Triple;

use crate::target::c::{CStd, CxxStd};
use crate::{tools, Beaver, BeaverError};
use crate::traits::{Project, Target};
use super::traits::Library;
use super::LibraryArtifactType;

#[derive(Debug, Clone)]
pub enum Dependency {
    Library(LibraryTargetDependency),

    Flags {
        cflags: Option<Vec<String>>,
        linker_flags: Option<Vec<String>>,
        headers: Option<Vec<PathBuf>>,
    },
    /// reference to a CMake id
    CMakeId(String),
    Multi(Vec<Dependency>),
    /// A file dependency, this can refer to any file (that isn't a source file)
    File(PathBuf),
}

impl Dependency {
    pub fn hash(&self, context: &Beaver) -> crate::Result<u64> {
        let mut h = DefaultHasher::new();
        self.hash_into(context, &mut h)?;
        return Ok(h.finish());
    }

    pub fn hash_into<H: Hasher>(&self, context: &Beaver, h: &mut H) -> crate::Result<()> {
        match self {
            Dependency::Library(lib) => {
                h.write_u8(0);
                let target = lib.target(context)?;
                h.write_usize(target.project);
                h.write_usize(target.target);
                lib.artifact(context)?.hash(h);
            },
            Dependency::Flags { cflags, linker_flags, headers } => {
                h.write_u8(1);
                if let Some(cflags) = cflags {
                    h.write_length_prefix(cflags.len());
                    for cflag in cflags {
                        h.write_str(cflag);
                    }
                } else {
                    h.write_length_prefix(0);
                }
                if let Some(linker_flags) = linker_flags {
                    h.write_length_prefix(linker_flags.len());
                    for linker_flag in linker_flags {
                        h.write_str(linker_flag);
                    }
                } else {
                    h.write_length_prefix(0);
                }
                if let Some(headers) = headers {
                    h.write_length_prefix(headers.len());
                    for header in headers {
                        h.write_str(&header.to_string_lossy());
                    }
                } else {
                    h.write_length_prefix(0);
                }
            },
            Dependency::CMakeId(id) => {
                h.write_u8(2);
                h.write_str(id);
            },
            Dependency::Multi(items) => {
                h.write_u8(3);
                h.write_length_prefix(items.len());
                for item in items {
                    item.hash_into(context, h)?;
                }
            },
            Dependency::File(path_buf) => {
                h.write_u8(4);
                h.write_str(&path_buf.to_string_lossy());
            },
        }

        Ok(())
    }
}

// Initializers //

pub enum PkgconfigOption<'a> {
    WithPath(&'a str),
}

impl<'a> PkgconfigOption<'a> {
    fn flag_into(&self, args: &mut Vec<OsString>) {
        match self {
            Self::WithPath(path) => args.push(OsString::from(format!("--with-path={}", path))),
        }
    }
}

pub enum PkgconfigFlagOption {
    PreferStatic,
}

impl PkgconfigFlagOption {
    fn flag_into(&self, args: &mut Vec<OsString>) {
        match self {
            Self::PreferStatic => args.push(OsString::from("--static")),
        }
    }
}

// Constructors
impl Dependency {
    // TODO: use pkg_config crate
    pub fn pkgconfig(name: &str, version_contstraint: Option<&str>, options: &[PkgconfigOption], flag_options: &[PkgconfigFlagOption]) -> crate::Result<Dependency> {
        let mut exists_args: Vec<OsString> = vec![OsString::from("--exists"), OsString::from(name), OsString::from("--print-errors")];
        for option in options {
            option.flag_into(&mut exists_args);
        }
        if let Some(version_contraint) = version_contstraint {
            let mut chars = version_contraint.chars();
            match chars.next() {
                Some('=') => {
                    exists_args.push(OsString::from(format!("--exact-version")));
                    exists_args.push(OsString::from(chars.collect::<String>()))
                },
                Some('>') => {
                    if chars.next() != Some('=') {
                        return Err(BeaverError::PkgconfigMalformedVersionRequirement(version_contraint.to_string()));
                    }
                    exists_args.push(OsString::from(format!("--atleast-version")));
                    exists_args.push(OsString::from(chars.collect::<String>()));
                },
                Some('<') => {
                    if chars.next() != Some('=') {
                        return Err(BeaverError::PkgconfigMalformedVersionRequirement(version_contraint.to_string()));
                    }
                    exists_args.push(OsString::from(format!("--max-version")));
                    exists_args.push(OsString::from(chars.collect::<String>()));
                },
                _ => return Err(BeaverError::PkgconfigMalformedVersionRequirement(version_contraint.to_string()))
            }
        }
        trace!("Invoking pkg-config exists for {} with args {:?}", name, &exists_args);
        let mut exists_process = Command::new(tools::pkgconf.as_os_str())
            .args(exists_args)
            .spawn()?;

        let mut flags_args: Vec<OsString> = vec![OsString::from("--cflags"), OsString::from(name), OsString::from("--print-errors")];
        for option in options {
            option.flag_into(&mut flags_args);
        }
        for flag_option in flag_options {
            flag_option.flag_into(&mut flags_args);
        }
        trace!("Invoking pkg-config for {} with args {:?}", name, &flags_args);
        let mut cflags_process = Command::new(tools::pkgconf.as_os_str())
            .args(&flags_args)
            .stderr(Stdio::inherit())
            .stdout(Stdio::piped())
            .spawn()?;
        flags_args[0] = OsString::from("--libs");
        trace!("Invoking pkg-config for {} with args {:?}", name, &flags_args);
        let mut linker_flags_process = Command::new(tools::pkgconf.as_os_str())
            .args(flags_args)
            .stderr(Stdio::inherit())
            .stdout(Stdio::piped())
            .spawn()?;

        // Check exists
        if !exists_process.wait()?.success() {
            if let Err(err) = cflags_process.kill() { error!("{:?}", err) }
            if let Err(err) = linker_flags_process.kill() { error!("{:?}", err) }
            return Err(BeaverError::PkgconfigNotFound(name.to_string()));
        }

        // Collect cflags
        let cflags_status = cflags_process.wait()?;
        if !cflags_status.success() {
            _ = linker_flags_process.kill().map_err(|err| error!("{:?}", err));
            return Err(BeaverError::NonZeroExitStatus(cflags_status));
        }
        let mut cflags_stdout = cflags_process.stdout.take().expect("Stdout should be captured");
        let mut string = String::new();
        cflags_stdout.read_to_string(&mut string)?;
        let Some(cflags) = shlex::split(&string) else {
            if let Err(err) = linker_flags_process.kill() { error!("{:?}", err) }
            return Err(BeaverError::PkgconfigMalformed(string));
        };

        // Collect linker flags
        let linker_flags_status = linker_flags_process.wait()?;
        if !linker_flags_status.success() {
            return Err(BeaverError::NonZeroExitStatus(linker_flags_status));
        }
        let mut linker_flags_stdout = linker_flags_process.stdout.take().expect("Stdout should be captured");
        let mut string = String::new();
        linker_flags_stdout.read_to_string(&mut string)?;
        let Some(linker_flags) = shlex::split(&string) else {
            return Err(BeaverError::PkgconfigMalformed(string));
        };

        Ok(Dependency::Flags { cflags: Some(cflags), linker_flags: Some(linker_flags), headers: None })
    }

    pub fn system(name: &str) -> Dependency {
        Dependency::Flags { cflags: None, linker_flags: Some(vec![format!("-l{}", name)]), headers: None }
    }

    pub fn framework(name: &str) -> Dependency {
        Dependency::Flags {
            cflags: None,
            linker_flags: Some(vec!["-framework".to_string(), name.to_string()]),
            headers: None
        }
    }

    pub fn pkgconfig_from_file(file: &Path, prepend_search_path: Option<&Path>) -> crate::Result<Dependency> {
        let contents = std::fs::read_to_string(file)?;
        let pkgconf = pkgconfig_parser::PkgConfig::parse(&contents)
            .map_err(|err| BeaverError::PkgconfigParsingError(file.to_path_buf(), err))?;

        let mut deps = vec![
            Dependency::Flags {
                cflags: pkgconf.cflags().as_ref().map(|cflags| shlex::split(cflags.as_ref()).unwrap()),
                linker_flags: pkgconf.libs().as_ref().map(|lflags| shlex::split(lflags.as_ref()).unwrap()),
                headers: None,
            }
        ];

        if let Some(mut dependencies) = crate::target::pkgconfig_collect_dependencies(&pkgconf, prepend_search_path)? {
            deps.append(&mut dependencies);
        }

        Ok(Dependency::Multi(deps))
    }
}

// LibraryTarget //

#[derive(Eq, PartialEq, Hash, Clone, Copy, Debug)]
pub struct TargetRef {
    pub target: usize,
    pub project: usize,
}

#[derive(Debug, Hash, PartialEq, Clone)]
pub enum LazyRef {
    Id(usize),
    Name(String),
}

#[derive(Debug, Hash, PartialEq, Clone)]
pub enum LazyLibraryArtifactType {
    Init(LibraryArtifactType),
    Default
}

#[derive(Debug, Hash, PartialEq, Clone)]
pub struct LazyTargetRef {
    pub project: LazyRef,
    pub target: LazyRef
}

#[derive(Debug, Clone)]
pub struct LibraryTargetDependency {
    dependency: OnceLock<(TargetRef, LibraryArtifactType)>,
    target_ref: Option<LazyTargetRef>,
    artifact: Option<LazyLibraryArtifactType>,
}

impl LibraryTargetDependency {
    pub fn new_init(tref: TargetRef, artifact: LibraryArtifactType) -> Self {
        LibraryTargetDependency { dependency: OnceLock::new_init((
            TargetRef {
                project: tref.project,
                target: tref.target
            },
            artifact
        )), target_ref: None, artifact: None }
    }

    pub fn new_lazy(tref: LazyTargetRef, artifact: LazyLibraryArtifactType) -> Self {
        LibraryTargetDependency {
            dependency: OnceLock::new(),
            target_ref: Some(tref),
            artifact: Some(artifact)
        }
    }

    fn get_init(&self, context: &Beaver) -> crate::Result<(TargetRef, LibraryArtifactType)> {
        let lazy_target_ref = self.target_ref.as_ref().unwrap();
        let target_ref = match (&lazy_target_ref.project, &lazy_target_ref.target) {
            (LazyRef::Id(projid), LazyRef::Id(targetid)) => TargetRef {
                target: *targetid,
                project: *projid
            },
            (LazyRef::Id(projid), LazyRef::Name(target)) => TargetRef {
                target: context.with_project(*projid, |proj| {
                    proj.find_target(&target)?
                        .ok_or_else(|| BeaverError::NoTargetNamed(target.clone(), proj.name().to_string()))
                })?,
                project: *projid
            },
            (LazyRef::Name(proj), LazyRef::Id(targetid)) => TargetRef {
                target: *targetid,
                project: context.find_project(&proj)?.ok_or_else(|| BeaverError::NoProjectNamed(proj.clone()))?
            },
            (LazyRef::Name(proj), LazyRef::Name(target)) => context.with_project_named(&proj, |proj| {
                Ok(TargetRef {
                    project: proj.id().unwrap(),
                    target: proj.find_target(&target)?
                        .ok_or_else(|| BeaverError::NoTargetNamed(target.clone(), proj.name().to_string()))?
                })
            })?
        };

        let lazy_artifact = self.artifact.as_ref().unwrap();
        let artifact = match lazy_artifact {
            LazyLibraryArtifactType::Init(lib_art) => lib_art.clone(),
            LazyLibraryArtifactType::Default => context.with_project_and_library::<LibraryArtifactType, BeaverError>(&target_ref, |_, lib| {
                    lib.default_library_artifact().or_else(|| lib.library_artifacts().first().cloned())
                        .ok_or_else(|| BeaverError::NoArtifacts(lib.name().to_string()))
                        .map(Ok)?
                })?
        };

        let dependency = (target_ref, artifact);

        Ok(dependency)
    }

    pub fn target(&self, context: &Beaver) -> crate::Result<&TargetRef> {
        return Ok(&self.dependency.get_or_try_init(|| self.get_init(context))?.0);
    }

    pub fn artifact(&self, context: &Beaver) -> crate::Result<&LibraryArtifactType> {
        return Ok(&self.dependency.get_or_try_init(|| self.get_init(context))?.1);
    }
}

// fns //

impl Dependency {
    pub(crate) fn ninja_name(&self, context: &Beaver) -> crate::Result<Option<String>> {
        match self {
            Dependency::Library(dep) => {
                return context.with_project_and_target::<Option<String>, BeaverError>(dep.target(context)?, |project, target| {
                    Ok(Some(format!("{}$:{}$:{}", project.name(), target.name(), dep.artifact(context)?)))
                });
            },
            Dependency::Flags { cflags: _, linker_flags: _, headers: _ } => {
                return Ok(None);
            },
            Dependency::CMakeId(cmake_id) => {
                return context.with_cmake_project_and_library(&cmake_id, |project, target| {
                    Ok(target.map(|target| format!("{}$:{}$:{}", project.name(), target.name(), target.artifact)))
                });
            },
            Dependency::Multi(_deps) => {
                return Ok(None); // TODO
            },
            Dependency::File(file) => {
                file.to_str()
                    .ok_or(BeaverError::NonUTF8OsStr(file.as_os_str().to_os_string()))
                    .map(|str| Some(str.to_string()))
            }
        }
    }

    pub(crate) fn ninja_name_not_escaped(&self, context: &Beaver) -> crate::Result<Option<String>> {
        match self {
            Dependency::Library(dep) => {
                return context.with_project_and_target::<Option<String>, BeaverError>(dep.target(context)?, |project, target| {
                    Ok(Some(format!("{}:{}:{}", project.name(), target.name(), dep.artifact(context)?)))
                });
            },
            Dependency::Flags { cflags: _, linker_flags: _, headers: _ } => {
                return Ok(None);
            },
            Dependency::CMakeId(cmake_id) => {
                return context.with_cmake_project_and_library(&cmake_id, |project, target| {
                    Ok(target.map(|target| format!("{}:{}:{}", project.name(), target.name(), target.artifact)))
                });
            },
            Dependency::Multi(_deps) => {
                return Ok(None); // TODO
            },
            Dependency::File(file) => {
                file.to_str()
                    .ok_or(BeaverError::NonUTF8OsStr(file.as_os_str().to_os_string()))
                    .map(|str| Some(str.to_string()))
            }
        }
    }

    pub(crate) fn public_cflags(&self, context: &Beaver, out: &mut Vec<String>, additional_file_dependencies: &mut Vec<PathBuf>) -> crate::Result<()> {
        match self {
            Dependency::Library(dep) => {
                context.with_project_and_target::<(), BeaverError>(dep.target(context)?, |proj, target| {
                    target.as_library().unwrap().public_cflags(proj.base_dir(), proj.build_dir(), out, additional_file_dependencies)
                })
            },
            Dependency::Flags { cflags, linker_flags: _, headers } => {
                if let Some(cflags) = cflags {
                    out.extend_from_slice(cflags.as_slice());
                }
                if let Some(headers) = headers {
                    context.with_current_project::<(), BeaverError>(|proj| {
                        for header in headers {
                            out.push(format!("-I{}", proj.base_dir().join(header).to_str()
                                .ok_or_else(|| BeaverError::NonUTF8OsStr(proj.base_dir().join(header).into_os_string()))?));
                        }
                        Ok(())
                    })?;
                }
                Ok(())
            },
            Dependency::CMakeId(cmake_id) => {
                context.with_cmake_project_and_library(&cmake_id, |project, target| {
                    if let Some(target) = target {
                        target.public_cflags(project.base_dir(), project.build_dir(), out, additional_file_dependencies)
                    } else {
                        debug!("dependency unused: {}", cmake_id);
                        Ok(())
                    }
                })
            },
            Dependency::Multi(deps) => {
                deps.iter().map(|dep| dep.public_cflags(context, out, additional_file_dependencies)).collect()
            },
            Dependency::File(_) => Ok(())
        }
    }

    pub(crate) fn linker_flags(&self, triple: &Triple, context: &Beaver, out: &mut Vec<String>, additional_files: &mut Vec<PathBuf>) -> crate::Result<()> {
        match self {
            Dependency::Library(dep) => {
                context.with_project_and_target::<(), BeaverError>(dep.target(context)?, |proj, target| {
                    target.as_library().unwrap().link_against_library(proj.build_dir(), *dep.artifact(context)?, &triple, out, additional_files)
                    // out.append(&mut target.as_library().unwrap().link_against_library(proj.build_dir(), dep.artifact, &triple)?);
                })
            },
            Dependency::Flags { cflags: _, linker_flags, headers: _ } => {
                if let Some(linker_flags) = linker_flags {
                    out.extend_from_slice(linker_flags.as_slice());
                }
                // return Ok(linker_flags.clone());
                Ok(())
            },
            Dependency::CMakeId(cmake_id) => {
                context.with_cmake_project_and_library(&cmake_id, |project, target| {
                    if let Some(target) = target {
                        target.link_against_library(project.build_dir(), target.artifact, &triple, out, additional_files)
                    } else {
                        debug!("dependency unused: {}", cmake_id);
                        Ok(())
                    }
                })
            },
            Dependency::Multi(deps) => {
                deps.iter().map(|dep| dep.linker_flags(triple, context, out, additional_files)).collect()
            },
            Dependency::File(_) => Ok(())
        }
    }

    pub(crate) fn min_cstd(&self, context: &Beaver) -> crate::Result<Option<CStd>> {
        Ok(match self {
            Dependency::Library(lib) => context.with_project_and_library::<_, BeaverError>(lib.target(context)?, |_, lib| {
                Ok(lib.min_cstd())
            }).unwrap(),
            _ => None, // TODO: support in flags()
        })
    }

    pub(crate) fn min_cxxstd(&self, context: &Beaver) -> crate::Result<Option<CxxStd>> {
        Ok(match self {
            Dependency::Library(lib) => context.with_project_and_library::<_, BeaverError>(lib.target(context)?, |_, lib| {
                Ok(lib.min_cxxstd())
            }).unwrap(),
            _ => None, // TODO: support in flags()
        })
    }
}
