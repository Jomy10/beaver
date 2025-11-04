use std::path::{Path, PathBuf};
use std::sync::OnceLock;

use globwalk::GlobWalker;
use atomic_refcell::AtomicRefCell;
use log::*;

use crate::BeaverError;

pub struct Files {
    walker: AtomicRefCell<Option<GlobWalker>>,
    files_storage: OnceLock<Vec<PathBuf>>,
}

impl Files {
    pub fn from_pat(pat: &str, base_dir: &Path) -> crate::Result<Files> {
        Self::from_pats(&[pat], base_dir)
    }

    pub fn from_pats(pats: &[&str], base_dir: &Path) -> crate::Result<Files> {
        trace!("Creating globwalk in {} with globs {:?}", base_dir.display(), pats);

        if pats.iter().find(|p| Path::new(p).is_absolute()).is_some() {
            let base_dir_str = base_dir.to_str().ok_or_else(|| BeaverError::NonUTF8OsStr(base_dir.as_os_str().to_os_string()))?;

            let (abs, mut rel): (Vec<&str>, Vec<&str>) = pats.iter().partition(|p| Path::new(p).is_absolute());
            let mut absolute = Vec::new();
            for abs in abs.iter() {
                if let Some(relative) = abs.strip_prefix(base_dir_str) {
                    rel.push(relative)
                } else {
                    absolute.push(abs);
                }
            }

            if absolute.len() > 0 {
                warn!("Sources outside of project's base directory are ignored {:?}", absolute);
                debug!("Sources outside of the the project base directory are currently not supported");
            }

            let walker = globwalk::GlobWalkerBuilder::from_patterns(base_dir, rel.as_slice())
                .follow_links(false)
                .build()?;
            Ok(Files { walker: AtomicRefCell::new(Some(walker)), files_storage: OnceLock::new() })
        } else {
            let walker = globwalk::GlobWalkerBuilder::from_patterns(base_dir, pats)
                .follow_links(false)
                .build()?;
            Ok(Files{ walker: AtomicRefCell::new(Some(walker)), files_storage: OnceLock::new() })
        }
    }

    pub(crate) fn resolve(&self) -> crate::Result<&Vec<PathBuf>> {
        self.files_storage.get_or_try_init(|| {
            let mut vec = Vec::new();
            let walker = self.walker.borrow_mut().take().unwrap();
            for entry in walker {
                let entry = entry?;
                if entry.file_type().is_file() {
                    vec.push(entry.path().to_path_buf())
                }
            }
            Ok(vec)
        })
    }
}

impl std::fmt::Debug for Files {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str("Files { ... }")
    }
}
