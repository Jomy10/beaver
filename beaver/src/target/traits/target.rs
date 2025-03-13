use std::collections::HashSet;
use std::path::{Path, PathBuf};
use std::sync::{Arc, RwLock};

use enum_dispatch::enum_dispatch;
use target_lexicon::Triple;
use url::Url;
use crate::backend::BackendBuilder;
use crate::target::{ArtifactType, Dependency, Language, TargetRef, Version};
use crate::Beaver;

use super::{AnyExecutable, AnyLibrary};

#[derive(Copy, Clone, Debug, PartialEq, Eq)]
pub enum TargetType {
    Library,
    Executable,
}

#[enum_dispatch]
pub trait Target: Send + Sync + std::fmt::Debug {
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
    fn dependencies(&self) -> &[Dependency];

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
        context: &Beaver
    ) -> crate::Result<String>;

    fn unique_dependencies_and_languages(&self, context: &Beaver) -> crate::Result<(std::collections::hash_set::IntoIter<Dependency>, std::collections::hash_set::IntoIter<Language>)> {
        let (set, lang) = self.unique_dependencies_and_languages_set(context)?;
        return Ok((set.into_iter(), lang.into_iter()));
    }

    /// Collect dependencies recursively into a set
    fn unique_dependencies_and_languages_set(&self, context: &Beaver) -> crate::Result<(HashSet<Dependency>, HashSet<Language>)> {
        let mut set = HashSet::<Dependency>::new();
        let mut languages = HashSet::<Language>::new();
        self.collect_unique_dependencies_and_languages(&mut set, &mut languages, context)?;
        return Ok((set, languages));
    }

    fn collect_unique_dependencies_and_languages<'a>(
        &'a self,
        into_set: &mut HashSet<Dependency>,
        into_language_set: &mut HashSet<Language>,
        context: &Beaver
    ) -> crate::Result<()> {
        for dep in self.dependencies().iter() {
            // insert dep
            if into_set.contains(dep) { continue }
            into_set.insert(dep.clone());

            // collect dep's dependencies
            match dep {
                Dependency::Library(target_dep) => {
                    context.with_project_and_target(&target_dep.target, |_, target| {
                        into_language_set.insert(target.language());
                        target.collect_unique_dependencies_and_languages(into_set, into_language_set, context)
                    })?;
                },
                Dependency::Flags { cflags: _, linker_flags: _ } => {},
                Dependency::CMakeId(cmake_id) => {
                    context.with_cmake_project_and_library(&cmake_id, |_, target| {
                        into_language_set.insert(target.language());
                        target.collect_unique_dependencies_and_languages(into_set, into_language_set, context)
                    })?;
                }
            }
        }

        return Ok(());
    }

    /// Debug attributes to print when using `--debug`
    fn debug_attributes(&self) -> Vec<(&'static str, String)>;
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
