use std::ffi::OsString;
use std::io::Read;
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

impl Dependency {
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
                return context.with_project_and_target(&dep.target, |project, target| {
                    Ok(Some(format!("{}$:{}$:{}", project.name(), target.name(), dep.artifact)))
                });
            },
            Dependency::Flags { cflags: _, linker_flags: _ } => {
                return Ok(None);
            }
        }
    }

    pub(crate) fn ninja_name_not_escaped(&self, context: &Beaver) -> crate::Result<Option<String>> {
        match self {
            Dependency::Library(dep) => {
                return context.with_project_and_target(&dep.target, |project, target| {
                    Ok(Some(format!("{}:{}:{}", project.name(), target.name(), dep.artifact)))
                });
            },
            Dependency::Flags { cflags: _, linker_flags: _ } => {
                return Ok(None);
            }
        }
    }

    pub(crate) fn public_cflags(&self, context: &Beaver, out: &mut Vec<String>) -> crate::Result<()> {
        match self {
            Dependency::Library(dep) => {
                context.with_project_and_target(&dep.target, |proj, target| {
                    out.append(&mut target.as_library().unwrap().public_cflags(proj.base_dir()));
                    Ok(())
                })
            },
            Dependency::Flags { cflags, linker_flags: _ } => {
                if let Some(cflags) = cflags {
                    out.extend_from_slice(cflags.as_slice());
                }
                Ok(())
            }
        }
    }

    pub(crate) fn linker_flags(&self, triple: &Triple, context: &Beaver, out: &mut Vec<String>) -> crate::Result<()> {
        match self {
            Dependency::Library(dep) => {
                context.with_project_and_target(&dep.target, |proj, target| {
                    out.append(&mut target.as_library().unwrap().link_against_library(proj.build_dir(), dep.artifact, &triple)?);
                    Ok(())
                })
            },
            Dependency::Flags { cflags: _, linker_flags } => {
                if let Some(linker_flags) = linker_flags {
                    out.extend_from_slice(linker_flags.as_slice());
                }
                // return Ok(linker_flags.clone());
                Ok(())
            }
        }
    }
}
