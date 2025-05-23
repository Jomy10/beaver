use std::ffi::OsString;
use std::io::Read;
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};

use log::*;
use target_lexicon::Triple;

use crate::{tools, Beaver, BeaverError};
use crate::traits::{Project, Target};
use super::traits::Library;
use super::LibraryArtifactType;

#[derive(Eq, PartialEq, Hash, Clone, Debug)]
pub enum Dependency {
    Library(LibraryTargetDependency),
    Flags {
        cflags: Option<Vec<String>>,
        linker_flags: Option<Vec<String>>,
    },
    /// reference to a CMake id
    CMakeId(String),
    Multi(Vec<Dependency>),
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

        Ok(Dependency::Flags { cflags: Some(cflags), linker_flags: Some(linker_flags) })
    }

    pub fn system(name: &str) -> Dependency {
        Dependency::Flags { cflags: None, linker_flags: Some(vec![format!("-l{}", name)]) }
    }

    pub fn framework(name: &str) -> Dependency {
        Dependency::Flags {
            cflags: None,
            linker_flags: Some(vec!["-framework".to_string(), name.to_string()])
        }
    }

    pub fn pkgconfig_from_file(file: &Path) -> crate::Result<Dependency> {
        let contents = std::fs::read_to_string(file)?;
        let pkgconf = pkgconfig_parser::PkgConfig::parse(&contents)
            .map_err(|err| BeaverError::PkgconfigParsingError(file.to_path_buf(), err))?;

        let mut deps = vec![
            Dependency::Flags {
                cflags: pkgconf.cflags().as_ref().map(|cflags| shlex::split(cflags.as_ref()).unwrap()),
                linker_flags: pkgconf.libs().as_ref().map(|lflags| shlex::split(lflags.as_ref()).unwrap())
            }
        ];

        if let Some(mut dependencies) = crate::target::pkgconfig_collect_dependencies(&pkgconf)? {
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

#[derive(Eq, PartialEq, Hash, Clone, Copy, Debug)]
pub struct LibraryTargetDependency {
    pub target: TargetRef,
    pub artifact: LibraryArtifactType,
}

// fns //

impl Dependency {
    pub(crate) fn ninja_name(&self, context: &Beaver) -> crate::Result<Option<String>> {
        match self {
            Dependency::Library(dep) => {
                return context.with_project_and_target::<Option<String>, BeaverError>(&dep.target, |project, target| {
                    Ok(Some(format!("{}$:{}$:{}", project.name(), target.name(), dep.artifact)))
                });
            },
            Dependency::Flags { cflags: _, linker_flags: _ } => {
                return Ok(None);
            },
            Dependency::CMakeId(cmake_id) => {
                return context.with_cmake_project_and_library(&cmake_id, |project, target| {
                    Ok(target.map(|target| format!("{}$:{}$:{}", project.name(), target.name(), target.artifact)))
                });
            },
            Dependency::Multi(_deps) => {
                return Ok(None); // TODO
            }
        }
    }

    pub(crate) fn ninja_name_not_escaped(&self, context: &Beaver) -> crate::Result<Option<String>> {
        match self {
            Dependency::Library(dep) => {
                return context.with_project_and_target::<Option<String>, BeaverError>(&dep.target, |project, target| {
                    Ok(Some(format!("{}:{}:{}", project.name(), target.name(), dep.artifact)))
                });
            },
            Dependency::Flags { cflags: _, linker_flags: _ } => {
                return Ok(None);
            },
            Dependency::CMakeId(cmake_id) => {
                return context.with_cmake_project_and_library(&cmake_id, |project, target| {
                    Ok(target.map(|target| format!("{}:{}:{}", project.name(), target.name(), target.artifact)))
                });
            },
            Dependency::Multi(_deps) => {
                return Ok(None); // TODO
            }
        }
    }

    pub(crate) fn public_cflags(&self, context: &Beaver, out: &mut Vec<String>, additional_file_dependencies: &mut Vec<PathBuf>) -> crate::Result<()> {
        match self {
            Dependency::Library(dep) => {
                context.with_project_and_target::<(), BeaverError>(&dep.target, |proj, target| {
                    target.as_library().unwrap().public_cflags(proj.base_dir(), proj.build_dir(), out, additional_file_dependencies)
                })
            },
            Dependency::Flags { cflags, linker_flags: _ } => {
                if let Some(cflags) = cflags {
                    out.extend_from_slice(cflags.as_slice());
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
            }
        }
    }

    pub(crate) fn linker_flags(&self, triple: &Triple, context: &Beaver, out: &mut Vec<String>, additional_files: &mut Vec<PathBuf>) -> crate::Result<()> {
        match self {
            Dependency::Library(dep) => {
                context.with_project_and_target::<(), BeaverError>(&dep.target, |proj, target| {
                    target.as_library().unwrap().link_against_library(proj.build_dir(), dep.artifact, &triple, out, additional_files)
                    // out.append(&mut target.as_library().unwrap().link_against_library(proj.build_dir(), dep.artifact, &triple)?);
                })
            },
            Dependency::Flags { cflags: _, linker_flags } => {
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
            }
        }
    }
}
