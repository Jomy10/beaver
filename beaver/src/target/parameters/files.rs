use std::path::{Path, PathBuf};
use glob::*;

use crate::BeaverError;

#[derive(Debug)]
pub struct Files {
    globset: GlobSet,
}

impl Files {
    pub fn from_pat(pat: &str) -> crate::Result<Files> {
        let mut globset = GlobSet::new();
        globset.add_glob(Glob::new(pat).map_err(|err| {
            BeaverError::GlobPatternError(pat.to_string(), err)
        })?);
        return Ok(Files { globset })
    }

    pub fn from_pats(pats: &[&str]) -> crate::Result<Files> {
        Self::from_pats_iter(pats.iter().map(|str| *str))
    }

    pub fn from_pats_iter<'a>(pats: impl Iterator<Item = &'a str>) -> crate::Result<Files> {
        let mut globset = GlobSet::new();
        for pat in pats {
            globset.add_glob(Glob::new(pat).map_err(|err| {
                BeaverError::GlobPatternError(pat.to_string(), err)
            })?);
        }
        Ok(Files { globset })
    }

    pub(crate) fn resolve(&self, in_dir: &Path) -> crate::Result<Vec<PathBuf>> {
        self.globset.files(in_dir).map_err(|err| err.into())
    }
}
