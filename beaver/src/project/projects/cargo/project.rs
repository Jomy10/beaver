use std::ops::Deref;
use std::path::{Path, PathBuf};
use std::sync::{Arc, RwLock};

use target_lexicon::Triple;

use crate::backend::{rules, BackendBuilder, BackendBuilderScope, BuildStep};
use crate::target::TargetRef;
use crate::traits::{self, AnyTarget, MutableProject, Target, TargetType};
use crate::{Beaver, BeaverError};

#[derive(Debug)]
pub struct Project {
    id: Option<usize>,
    name: String,
    cargo_flags: Arc<Vec<String>>,
    base_dir: PathBuf,
    build_dir: PathBuf,
    targets: Vec<AnyTarget>,
}

impl Project {
    pub(crate) fn new(
        name: String,
        cargo_flags: Arc<Vec<String>>,
        base_dir: PathBuf,
        targets: Vec<AnyTarget>,
        context: &Beaver
    ) -> Self {
        let build_dir = base_dir.join("target").join(context.optimize_mode.cargo_name());
        let mut targets = targets;
        for i in 0..targets.len() {
            targets[i].set_id(i);
        }

        Self {
            id: None,
            name,
            cargo_flags,
            base_dir,
            build_dir,
            targets,
        }
    }
}

impl traits::Project for Project {
    fn id(&self) -> Option<usize> {
        self.id
    }

    fn set_id(&mut self, new_id: usize) -> crate::Result<()> {
        self.id = Some(new_id);
        for i in 0..self.targets.len() {
            self.targets[i].set_project_id(new_id);
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

    fn update_build_dir(&mut self, _: &Path) {
        panic!("Build directory for Cargo project cannot be set")
    }

    fn targets<'a>(&'a self) -> crate::Result<Box<dyn Deref<Target = Vec<AnyTarget>> + 'a>> {
        Ok(Box::new(&self.targets))
    }

    fn find_target(&self, name: &str) -> crate::Result<Option<usize>> {
        Ok(self.targets.iter().find(|target| target.name() == name).map(|target| target.id().unwrap()))
    }

    // TODO: generic implementation
    fn default_executable(&self) -> crate::Result<TargetRef> {
        let mut exe: Option<TargetRef> = None;
        for target in self.targets.iter() {
            if target.r#type() == TargetType::Executable {
                if exe.is_some() {
                    return Err(BeaverError::ManyExecutable {
                        project: self.name.clone(),
                        targets: self.targets.iter()
                            .filter(|target| target.r#type() == TargetType::Executable)
                            .map(|target| target.name().to_string())
                            .collect()
                    })
                } else {
                    exe = target.tref()
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
        _scope: &rayon::Scope,
        triple: &Triple,
        builder: Arc<RwLock<Builder>>,
        context: &Beaver,
    ) -> crate::Result<()> {
        let mut guard = builder.write().map_err(|err| BeaverError::BackendLockError(err.to_string()))?;
        guard.add_rule_if_not_exists(&rules::CARGO);
        guard.add_rule_if_not_exists(&rules::CARGO_WORKSPACE);
        #[cfg(debug_assertions)] { guard.add_comment(&self.name)?; }
        let mut scope = guard.new_scope();
        drop(guard);

        let base_abs = std::path::absolute(&self.base_dir)?;
        let Some(dir) = base_abs.to_str() else {
            return Err(BeaverError::NonUTF8OsStr(self.base_dir.as_os_str().to_os_string()));
        };

        for target in &self.targets {
            _ = target.register(
                &self.name,
                &self.base_dir,
                &self.build_dir,
                triple,
                builder.clone(),
                &mut scope,
                context
            )?;
        }

        scope.add_step(&BuildStep::Cmd {
            rule: &rules::CARGO_WORKSPACE,
            name: &self.name,
            dependencies: &[],
            options: &[
                ("workspaceDir", dir),
                ("cargoArgs", &(self.cargo_flags.join(" ") + if context.color_enabled() { " --color always " } else { "" } + context.optimize_mode.cargo_flags().join(" ").as_str()))
            ],
        })?;

        let mut guard = builder.write().map_err(|err| BeaverError::BackendLockError(err.to_string()))?;
        guard.apply_scope(scope);

        // TODO apply scope
        Ok(())
    }

    fn as_mutable(&self) -> Option<&dyn MutableProject> {
        None
    }
}
