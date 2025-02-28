use std::cell::RefCell;
use std::collections::HashSet;
use std::path::{Path, PathBuf};
use std::rc::Rc;
use std::sync::{Arc, RwLock};

use enum_dispatch::enum_dispatch;
use target_lexicon::Triple;
use url::Url;
use crate::backend::BackendBuilder;
use crate::target::{Version, Language, ArtifactType, Dependency};
use crate::Beaver;

use super::{AnyExecutable, AnyLibrary};

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

    fn artifacts(&self) -> Vec<ArtifactType>;
    fn dependencies(&self) -> &Vec<Dependency>;

    fn r#type(&self) -> TargetType;

    /// Default artifact to link against
    fn default_artifact(&self) -> Option<ArtifactType>;
    fn artifact_output_dir(&self, project_build_dir: &Path, triple: &Triple) -> PathBuf;
    fn artifact_file(&self, project_build_dir: &Path, artifact: ArtifactType, triple: &Triple) -> crate::Result<PathBuf>;

    fn register<Builder: BackendBuilder<'static>>(&self,
        project_name: &str,
        project_base_dir: &Path,
        project_build_dir: &Path,
        triple: &Triple,
        builder: Arc<RwLock<Builder>>,
        context: &Beaver
    ) -> crate::Result<()>;

    fn unique_dependencies(&self, context: &Beaver) -> crate::Result<std::collections::hash_set::IntoIter<Dependency>> {
        let set = self.unique_dependencies_set(context)?;
        return Ok(set.into_iter());
    }

    fn unique_dependencies_set(&self, context: &Beaver) -> crate::Result<HashSet<Dependency>> {
        let set = Rc::new(RefCell::new(HashSet::<Dependency>::new()));
        self.collect_unique_dependencies(set.clone(), context)?;
        let set = Rc::try_unwrap(set).unwrap(); // there should be no references alive at this point
        let set = set.into_inner();
        return Ok(set);
    }

    fn collect_unique_dependencies<'a>(&'a self, into_set: Rc<RefCell<HashSet<Dependency>>>, context: &Beaver) -> crate::Result<()> {
        for dep in self.dependencies().iter() {
            let mut set = into_set.borrow_mut();
            if set.contains(dep) { continue }
            set.insert(*dep);
            drop(set);
            match dep {
                Dependency::Library(target_dep) => {
                    context.with_project_and_target(&target_dep.target, |_, target| {
                       target.collect_unique_dependencies(into_set.clone(), context)
                    })?;
                }
            }
        }

        return Ok(());
    }
}

// macro_rules! target_fn_impl {
//     ($self: expr, $fn: ident) => {
//         match $self {
//             Self::Library(lib) => lib.$fn(),
//             Self::Executable(exe) => exe.$fn()
//         }
//     };
//     ($self: expr, $fn: ident, $($arg: expr),+) => {
//         match $self {
//             Self::Library(lib) => lib.$fn($($arg,)*),
//             Self::Executable(exe) => exe.$fn($($arg,)*)
//         }
//     };
// }

// macro_rules! target_fn {
//     ($fn: ident -> $ret: ty) => {
//         fn $fn(&self) -> $ret {
//             target_fn_impl!(self, $fn)
//         }
//     };
// }

// macro_rules! target_fn_mut {
//     ($fn: ident, $($arg: ident: $arg_ty: ty),+) => {
//         fn $fn(&mut self, $($arg: $arg_ty)*) {
//             target_fn_impl!(self, $fn, $($arg)*)
//         }
//     }
// }

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

// impl Target for AnyTarget {
//     target_fn!(name -> &str);
//     target_fn!(description ->Option<&str>);
//     target_fn!(homepage -> Option<&Url>);
//     target_fn!(version -> Option<&Version>);
//     target_fn!(license -> Option<&str>);
//     target_fn!(language -> Language);
//     target_fn!(id -> Option<usize>);
//     target_fn_mut!(set_id, new_id: usize);
//     target_fn!(project_id -> Option<usize>);
//     target_fn_mut!(set_project_id, new_id: usize);
//     target_fn!(artifacts -> Vec<ArtifactType>);
//     target_fn!(dependencies -> &Vec<Dependency>);
//     target_fn!(r#type -> TargetType);

//     fn artifact_output_dir(&self, project_build_dir: &Path, triple: &Triple) -> PathBuf {
//         target_fn_impl!(self, artifact_output_dir, project_build_dir, triple)
//     }

//     fn artifact_file(&self, project_build_dir: &Path, artifact: ArtifactType, triple: &Triple) -> crate::Result<PathBuf> {
//         target_fn_impl!(self, artifact_file, project_build_dir, artifact, triple)
//     }

//     fn register(&self,
//         project_name: &str,
//         project_base_dir: &Path,
//         project_build_dir: &Path,
//         triple: &Triple,
//         builder: Arc<RwLock<Box<dyn BackendBuilder>>>,
//         context: &Beaver
//     ) -> crate::Result<()> {
//         target_fn_impl!(self, register, project_name, project_base_dir, project_build_dir, triple, builder, context)
//     }
// }

// impl AnyTarget {
//     pub(crate) fn as_library(&self) -> Option<&Box<dyn Library>> {
//         match self {
//             Self::Library(lib) => Some(lib),
//             _ => None
//         }
//     }

//     #[allow(unused)]
//     pub(crate) fn as_executable(&self) -> Option<&Box<dyn Executable>> {
//         match self {
//             Self::Executable(exe) => Some(exe),
//             _ => None
//         }
//     }
// }

// unsafe impl Send for AnyTarget {}
// unsafe impl Sync for AnyTarget {}
