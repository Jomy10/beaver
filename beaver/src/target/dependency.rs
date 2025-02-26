use target_lexicon::Triple;

use crate::Beaver;
use crate::traits::{Project, Target};

use super::traits::Library;
use super::LibraryArtifactType;

#[derive(Eq, PartialEq, Hash, Copy, Clone, Debug)]
pub enum Dependency {
    Library(LibraryTargetDependency),
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
        }
    }

    pub(crate) fn public_cflags(&self, context: &Beaver) -> crate::Result<Option<Vec<String>>> {
        match self {
            Dependency::Library(dep) => {
                return context.with_project_and_target(&dep.target, |proj, target| {
                    Ok(Some(target.as_library().unwrap().public_cflags(proj.base_dir())))
                })
            }
        }
    }

    pub(crate) fn linker_flags(&self, triple: &Triple, context: &Beaver) -> crate::Result<Option<Vec<String>>> {
        match self {
            Dependency::Library(dep) => {
                return context.with_project_and_target(&dep.target, |proj, target| {
                    Ok(Some(target.as_library().unwrap().link_against_library(proj.build_dir(), dep.artifact, &triple)?))
                })
            }
        }
    }
}
