use std::fs::{self, DirEntry};
use std::path::{Path, PathBuf};

use crate::{Glob, GlobIterationError, PathSegment};

pub struct GlobSet {
    globs: Vec<Glob>,
    include_dirs: bool
}

impl GlobSet {
    pub fn new() -> Self {
        GlobSet {
            globs: Vec::new(),
            include_dirs: false
        }
    }

    pub fn add_glob(&mut self, glob: Glob) {
        self.globs.push(glob);
    }

    pub fn with_glob(&mut self, glob: Glob) -> &mut Self {
        self.globs.push(glob);
        return self;
    }

    fn collect_matches_of_dir(&self, path: &Path, globs: Vec<(usize, &Glob)>, paths: &mut Vec<PathBuf>) -> Result<(), GlobIterationError> {
        for entry in fs::read_dir(path)? {
            let entry = entry?;
            self.collect_entry_matches(entry, &globs, paths)?;
        }

        return Ok(());
    }

    fn collect_entry_matches(&self, entry: DirEntry, globs: &Vec<(usize, &Glob)>, paths: &mut Vec<PathBuf>) -> Result<(), GlobIterationError> {
        let file_type = entry.file_type()?;
        if !(file_type.is_dir() || file_type.is_file()) {
            return Ok(());
        }

        // globs in which to continue searching
        let mut matched_globs: Vec<(usize, &Glob)> = Vec::new();
        let mut matched_self = false;
        for (i, glob) in globs {
            let Some(segment) = glob.segment(*i) else {
                continue;
            };

            match segment {
                PathSegment::AnyPathSegment => {
                    if glob.has_more_segments(*i) {
                        if file_type.is_dir() {
                            matched_globs.push((*i, glob));
                            matched_globs.push((*i + 1, glob));
                        } else {
                            matched_globs.push((*i + 1, glob));
                        }
                    } else {
                        if self.include_dirs && file_type.is_dir() {
                            if !matched_self {
                                paths.push(entry.path());
                                matched_self = true;
                            }
                        } else if file_type.is_file() {
                            paths.push(entry.path());
                            matched_self = true;
                            break;
                        }
                    }
                },
                PathSegment::Segment(regex) => {
                    if regex.is_match(entry.file_name().to_str().unwrap()) {
                        if glob.has_more_segments(*i) {
                            if file_type.is_dir() {
                                matched_globs.push((*i + 1, glob));
                            }
                        } else {
                            if self.include_dirs && file_type.is_dir() {
                                if !matched_self {
                                    paths.push(entry.path());
                                    matched_self = true;
                                }
                            } else if file_type.is_file() {
                                paths.push(entry.path());
                                matched_self = true;
                                break;
                            }
                            break;
                        }
                    }
                }
            }
        }

        if matched_globs.len() > 0 {
            if file_type.is_dir() {
                self.collect_matches_of_dir(&entry.path(), matched_globs, paths)?;
            } else if !matched_self {
                self.collect_entry_matches(entry, &matched_globs, paths)?;
            }
        }

        return Ok(());
    }

    // TODO: AsyncStream
    /// Will not match symlinks
    pub fn files(&self, base_path: &Path) -> Result<Vec<PathBuf>, GlobIterationError> {
        let mut paths: Vec<PathBuf> = Vec::new();

        if !base_path.is_dir() {
            return Err(GlobIterationError::BasePathNotDirectory);
        }

        self.collect_matches_of_dir(base_path, self.globs.iter().map(|g| (0, g)).collect(), &mut paths)?;

        return Ok(paths);
    }
}

impl From<Vec<Glob>> for GlobSet {
    fn from(globs: Vec<Glob>) -> Self {
        GlobSet { globs, include_dirs: false }
    }
}

#[cfg(test)]
mod test {
    use super::*;

    #[test]
    fn module_ls() {
        let mut globset = GlobSet::new();
        globset.add_glob(Glob::new("src/*.rs").unwrap());
        let mut files = globset.files(&std::env::current_dir().unwrap()).unwrap()
            .into_iter()
            .map(|f| f.file_name().unwrap().to_str().unwrap().to_string())
            .collect::<Vec<String>>();
        files.sort();
        let mut expected = vec!["error.rs", "glob.rs", "glob_set.rs", "lib.rs"];
        expected.sort();

        assert_eq!(files, expected);
    }
}
