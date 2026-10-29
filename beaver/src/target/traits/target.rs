use std::borrow::Cow;
use std::collections::HashSet;
use std::path::{Path, PathBuf};
use std::sync::{Arc, RwLock};

use enum_dispatch::enum_dispatch;
use log::debug;
use target_lexicon::Triple;
use url::Url;
use crate::backend::BackendBuilder;
use crate::target::{self, ArtifactType, Dependency, Language, TargetRef, Version};
use crate::{Beaver, BeaverError};

use super::{AnyExecutable, AnyLibrary};

#[derive(Copy, Clone, Debug, PartialEq, Eq)]
pub enum TargetType {
    Library,
    Executable,
}

#[derive(Copy, Clone, Debug, PartialEq, Eq)]
pub enum TargetKind {
    C,
    Cargo,
    CMake,
    Custom,
    Meson,
    Spm,
}

impl std::fmt::Display for TargetKind {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_fmt(format_args!("{:?} target", self))
    }
}

#[enum_dispatch]
pub trait Target: Send + Sync + std::fmt::Debug {
    fn target_kind(&self) -> TargetKind;

    // General Info //
    fn name(&self) -> &str;
    fn description(&self) -> Option<&str>;
    fn homepage(&self) -> Option<&Url>;
    fn version(&self) -> Option<&Version>;
    fn license(&self) -> Option<&str>;
    fn language(&self) -> Language;

    // Identification //
    fn id(&self) -> Option<usize>;
    fn set_id(&mut self, new_id: usize);
    fn project_id(&self) -> Option<usize>;
    fn set_project_id(&mut self, new_id: usize);
    fn tref(&self) -> Option<TargetRef> {
        match (self.project_id(), self.id()) {
            (Some(project_id), Some(target_id)) => {
                Some(TargetRef {
                    project: project_id,
                    target: target_id
                })
            },
            _ => None
        }
    }

    fn artifacts(&self) -> Vec<ArtifactType>;
    fn dependencies<'a>(&'a self) -> crate::Result<Cow<'a, [Dependency]>>;

    fn r#type(&self) -> TargetType;

    fn artifact_file(&self, project_build_dir: &Path, artifact: ArtifactType, triple: &Triple) -> crate::Result<PathBuf>;

    /// Returns the target name
    fn register<Builder: BackendBuilder<'static>>(&self,
        project_name: &str,
        project_base_dir: &Path,
        project_build_dir: &Path,
        triple: &Triple,
        builder: Arc<RwLock<Builder>>,
        scope: &mut Builder::Scope,
        context: &Arc<Beaver>
    ) -> crate::Result<String>;

    fn unique_dependencies_and_languages<'a>(&'a self, context: &Beaver) -> crate::Result<(std::vec::IntoIter<Dependency>, std::collections::hash_set::IntoIter<Language>)> {
        let (_, deps, lang) = self.unique_dependencies_and_languages_set(context)?;
        return Ok((deps.into_iter(), lang.into_iter()));
    }

    /// Collect dependencies recursively into a set
    fn unique_dependencies_and_languages_set<'a>(&'a self, context: &Beaver) -> crate::Result<(HashSet<u64>, Vec<Dependency>, HashSet<Language>)> {
        let mut set = HashSet::<u64>::new(); // Set of dependencies visited
        let mut deps = Vec::new();
        let mut languages = HashSet::<Language>::new();
        self.collect_unique_dependencies_and_languages(&mut set, &mut deps, &mut languages, context)?;
        return Ok((set, deps, languages));
    }

    fn collect_unique_dependencies_and_languages(
        &self,
        into_set: &mut HashSet<u64>,
        deps: &mut Vec<Dependency>,
        into_language_set: &mut HashSet<Language>,
        context: &Beaver
    ) -> crate::Result<()> {
        for dep in self.dependencies()?.iter() {
            collect_dependency_and_languages(dep, into_set, deps, into_language_set, context)?;
        }

        return Ok(());
    }

    /// Debug attributes to print when using `--debug`
    fn debug_attributes(&self) -> Vec<(&'static str, String)>;

    fn add_dependency(&mut self, _: Dependency) -> crate::Result<()> {
        return Err(crate::BeaverError::TargetOperationNotSupported("add_dependency".to_string(), self.target_kind().to_string()));
    }

    /// Adds cflags to the target's private cflags
    fn add_cflags(&mut self, cflags: &[String]) -> crate::Result<()>;

    /// Adds linker flags to the target's private linker flags
    fn add_linker_flags(&mut self, linker_flags: &[String]) -> crate::Result<()>;
}

fn collect_dependency_and_languages(dep: &Dependency, into_set: &mut HashSet<u64>, deps: &mut Vec<Dependency>, into_language_set: &mut HashSet<Language>, context: &Beaver) -> crate::Result<()> {
    // insert dep
    let dep_hash = dep.hash(context)?;
    if into_set.contains(&dep_hash) { return Ok(()); }
    into_set.insert(dep_hash);
    deps.push(dep.clone());

    // collect dep's dependencies
    match dep {
        Dependency::Library(target_dep) => {
            context.with_project_and_target::<(), BeaverError>(target_dep.target(context)?, |_, target| {
                into_language_set.insert(target.language());
                target.collect_unique_dependencies_and_languages(into_set, deps, into_language_set, context)
            })?;
        },
        Dependency::Flags { cflags: _, linker_flags: _, headers: _ } => {},
        Dependency::CMakeId(cmake_id) => {
            context.with_cmake_project_and_library(&cmake_id, |_, target| {
                if let Some(target) = target {
                    into_language_set.insert(target.language());
                    target.collect_unique_dependencies_and_languages(into_set, deps, into_language_set, context)
                } else {
                    debug!("Unmapped dependency {}", cmake_id);
                    Ok(())
                }
            })?;
        },
        Dependency::Multi(multi_deps) => {
            for dep in multi_deps {
                collect_dependency_and_languages(dep, into_set, deps, into_language_set, context)?;
            }
        },
        Dependency::File(_) => {
            // into_set.insert(dep);
        }
    }

    Ok(())
}

#[enum_dispatch(Target)]
#[derive(Debug)]
pub enum AnyTarget {
    Library(AnyLibrary),
    Executable(AnyExecutable),
}

impl AnyTarget {
    pub(crate) fn as_library(&self) -> Option<&AnyLibrary> {
        match self {
            Self::Library(lib) => Some(lib),
            _ => None
        }
    }

    #[allow(unused)]
    pub(crate) fn as_executable(&self) -> Option<&AnyExecutable> {
        match self {
            Self::Executable(exe) => Some(exe),
            _ => None
        }
    }
}

impl From<target::spm::Library> for AnyTarget {
    fn from(value: target::spm::Library) -> Self {
        AnyTarget::Library(AnyLibrary::SPM(value))
    }
}

impl From<target::spm::Executable> for AnyTarget {
    fn from(value: target::spm::Executable) -> Self {
        AnyTarget::Executable(AnyExecutable::SPM(value))
    }
}
