use std::ops::Deref;
use std::path::{Path, PathBuf};
use std::sync::{Arc, RwLock};

use target_lexicon::Triple;

use crate::backend::{rules, BackendBuilder, BackendBuilderScope, BuildStep};
use crate::target::TargetRef;
use crate::traits::{self, AnyTarget, Target, TargetType};
use crate::{Beaver, BeaverError};

#[derive(Debug)]
pub struct Project {
    id: Option<usize>,
    name: String,
    base_dir: PathBuf,
    build_dir: PathBuf,
    targets: Vec<AnyTarget>,
}

impl Project {
    pub fn new(
        name: String,
        base_dir: PathBuf,
        build_dir: PathBuf,
        targets: Vec<AnyTarget>
    ) -> Self {
        Self {
            id: None,
            name,
            base_dir,
            build_dir,
            targets
        }
    }
}

impl traits::Project for Project {
    fn id(&self) -> Option<usize> {
        self.id
    }

    fn set_id(&mut self, new_id: usize) -> crate::Result<()> {
        self.id = Some(new_id);
        for target in &mut self.targets {
            target.set_id(new_id);
        }
        Ok(())
    }

    fn name(&self) -> &str {
        &self.name
    }

    fn base_dir(&self) -> &Path {
        &self.base_dir
    }

    fn build_dir(&self) -> &Path {
        &self.build_dir
    }

    // TODO: do we need this in general anymore?
    fn update_build_dir(&mut self, _new_base_build_dir: &Path) {
        panic!("CMake Project's build dir cannot be updated")
    }

    fn targets<'a>(&'a self) -> std::result::Result<Box<(dyn Deref<Target = Vec<AnyTarget>> + 'a)>, BeaverError> {
        Ok(Box::new(&self.targets))
    }

    fn find_target(&self, name: &str) -> crate::Result<Option<usize>> {
        for (i, target) in self.targets.iter().enumerate() {
            if target.name() == name {
                return Ok(Some(i));
            }
        }
        Ok(None)
    }

    fn default_executable(&self) -> crate::Result<TargetRef> {
        let mut exe: Option<TargetRef> = None;
        for target in &self.targets {
            if target.r#type() == TargetType::Executable {
                if exe.is_none() {
                    exe = target.tref()
                } else {
                    return Err(BeaverError::ManyExecutable { project: self.name.clone(), targets: self.targets.iter()
                        .filter(|target| target.r#type() == TargetType::Executable)
                        .map(|target| target.name().to_string()).collect()
                    })
                }
            }
        }

        if let Some(exe) = exe {
            Ok(exe)
        } else {
            Err(BeaverError::NoExecutable(self.name.clone()))
        }
    }

    fn register<Builder: BackendBuilder<'static>>(
        &self,
        scope: &rayon::Scope,
        triple: &Triple,
        builder: Arc<RwLock<Builder>>,
        context: &Beaver,
    ) -> crate::Result<()> {
        _ = scope; // TODO

        let (mut guard, _) = self.register_targets(triple, &builder, context)?;

        let Some(project_build_dir_str) = self.build_dir.as_os_str().to_str() else {
            return Err(BeaverError::NonUTF8OsStr(self.build_dir.as_os_str().to_os_string()));
        };

        let mut scope = guard.new_scope();
        #[cfg(debug_assertions)] {
            scope.add_comment(&format!("CMake Project: {}", self.name()))?;
        }
        scope.add_step(&BuildStep::Cmd {
            rule: &rules::NINJA,
            name: &self.name,
            dependencies: &[],
            options: &[
                ("ninjaBaseDir", project_build_dir_str),
                ("ninjaFile", "build.ninja"),
                ("targets", "all")
            ],
        })?;

        guard.apply_scope(scope);

        return Ok(());
    }

    fn as_mutable(&self) -> Option<&dyn traits::MutableProject> {
        None
    }
}
