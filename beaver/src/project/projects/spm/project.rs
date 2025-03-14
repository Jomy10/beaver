use std::ops::Deref;
use std::path::{Path, PathBuf};
use std::sync::{Arc, RwLock};

use target_lexicon::Triple;

use crate::backend::BackendBuilder;
use crate::traits::{self, AnyTarget, MutableProject, Target};
use crate::Beaver;

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
        global_build_dir: &Path,
        targets: Vec<AnyTarget>,
    ) -> Self {
        let build_dir = global_build_dir.join(&name);

        Self {
            id: None,
            name,
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

    fn update_build_dir(&mut self, new_base_build_dir: &Path) {
        self.build_dir = new_base_build_dir.join(&self.name)
    }

    fn targets<'a>(&'a self) -> crate::Result<Box<dyn Deref<Target = Vec<AnyTarget>> + 'a>> {
        Ok(Box::new(&self.targets))
    }

    fn find_target(&self, name: &str) -> crate::Result<Option<usize>> {
        Ok(self.targets.iter().find(|target| target.name() == name)
            .map(|target| target.id().unwrap()))
    }

    fn register<Builder: BackendBuilder<'static>>(
        &self,
        scope: &rayon::Scope,
        triple: &Triple,
        builder: Arc<RwLock<Builder>>,
        context: &Beaver,
    ) -> crate::Result<()> {
        todo!()
    }

    fn as_mutable(&self) -> Option<&dyn MutableProject> {
        None
    }
}
