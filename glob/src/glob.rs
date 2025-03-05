use std::fs::{self, DirEntry};
use std::ops::Range;
use std::path::{Path, PathBuf};

use regex::Regex;
use unicode_segmentation::UnicodeSegmentation;

use crate::{GlobError, GlobIterationError};

#[derive(Debug)]
pub struct Glob {
    components: Vec<PathSegment>
}

impl Glob {
    pub fn new(pat: &str) -> Result<Glob, GlobError> {
        Ok(Glob {
            components: Glob::segment_iterator(pat).map(|segment| {
                Glob::parse_segment(segment)
            }).collect::<Result<Vec<PathSegment>, GlobError>>()?
        })
    }

    fn segment_iterator<'a>(pat: &'a str) -> SegmentIterator<'a> {
        let chars = pat.grapheme_indices(true);
        let mut segments: Vec<Range<usize>> = Vec::new();
        let mut start = 0;
        for (i, c) in chars {
            if c == "/" {
                segments.push(start..i);
                start = i + 1
            }
        }
        segments.push(start..pat.len());
        return SegmentIterator { storage: pat, segments: segments.into_iter() };
    }

    fn parse_segment(segment: &str) -> Result<PathSegment, GlobError> {
        if segment == "**" {
            return Ok(PathSegment::AnyPathSegment)
        } else {
            let mut strbuf: String = String::new();
            let mut escape = false;
            for char in segment.graphemes(true) {
                match char {
                    "\\" => {
                        if escape {
                            strbuf.push_str("\\\\");
                            escape = false;
                        } else {
                            escape = true
                        }
                    },
                    "*" => {
                        if escape {
                            strbuf.push_str("\\*");
                            escape = false;
                        } else {
                            strbuf.push_str(".*");
                        }
                    },
                    "?" => {
                        if escape {
                            strbuf.push_str("\\?");
                            escape = false;
                        } else {
                            strbuf.push_str(".");
                        }
                    },
                    // TODO: {} and [] and [!...]
                    //   -> see: https://code.visualstudio.com/docs/editor/glob-patterns#_glob-pattern-syntax
                    "|" | "+" | "{" | "}" | "(" | ")" | "[" | "]" | "." | "^" | "$" => {
                      strbuf.push_str("\\");
                      strbuf.push_str(char);
                    },
                    _ => {
                        if escape {
                            return Err(GlobError::InvalidEscape(format!("\\{}", char)));
                        }
                        strbuf.push_str(char);
                    }
                }
            }
            return Ok(PathSegment::Segment(Regex::new(&strbuf).unwrap()));
        }
    }

    pub(crate) fn segment(&self, idx: usize) -> Option<&PathSegment> {
        self.components.get(idx)
    }

    pub(crate) fn segment_count(&self) -> usize {
        self.components.len()
    }

    pub(crate) fn has_more_segments(&self, idx: usize) -> bool {
        idx + 1 < self.segment_count()
    }
}

impl Glob {
    fn collect_matches_of_dir(&self, path: &Path, idx: usize, paths: &mut Vec<PathBuf>, include_dirs: bool) -> Result<(), GlobIterationError> {
        for entry in fs::read_dir(path)? {
            let entry = entry?;
            self.collect_entry_matches(entry, idx, paths, include_dirs)?;
        }

        return Ok(());
    }

    fn collect_entry_matches(&self, entry: DirEntry, idx: usize, paths: &mut Vec<PathBuf>, include_dirs: bool) -> Result<(), GlobIterationError> {
        let file_type = entry.file_type()?;
        if !(file_type.is_dir() || file_type.is_file()) {
            return Ok(());
        }

        let Some(segment) = self.segment(idx) else {
            return Ok(());
        };

        match segment {
            PathSegment::AnyPathSegment => {
                if self.has_more_segments(idx) {
                    if file_type.is_dir() {
                        self.collect_matches_of_dir(&entry.path(), idx, paths, include_dirs)?;
                        return self.collect_matches_of_dir(&entry.path(), idx + 1, paths, include_dirs);
                    } else {
                        return self.collect_entry_matches(entry, idx + 1, paths, include_dirs);
                    }
                } else {
                    if include_dirs && file_type.is_dir() {
                        paths.push(entry.path());
                        return Ok(());
                    } else if file_type.is_file() {
                        paths.push(entry.path());
                        return Ok(());
                    } else {
                        return Ok(());
                    }
                }
            },
            PathSegment::Segment(regex) => {
                if regex.is_match(entry.file_name().to_str().unwrap()) {
                    if self.has_more_segments(idx) {
                        if file_type.is_dir() {
                            return self.collect_matches_of_dir(&entry.path(), idx + 1, paths, include_dirs);
                        } else {
                            return Ok(());
                        }
                    } else {
                        if include_dirs && file_type.is_dir() {
                            paths.push(entry.path());
                            return Ok(());
                        } else if file_type.is_file() {
                            paths.push(entry.path());
                            return Ok(());
                        } else {
                            return Ok(());
                        }
                    }
                } else {
                    return Ok(());
                }
            }
        }
    }

    /// Collect all matches for a single glob (only includes files, not directories)
    pub fn files(&self, base_path: &Path) -> Result<Vec<PathBuf>, GlobIterationError> {
        let mut paths: Vec<PathBuf> = Vec::new();

        if !base_path.is_dir() {
            return Err(GlobIterationError::BasePathNotDirectory);
        }

        self.collect_matches_of_dir(base_path, 0, &mut paths, false)?;

        return Ok(paths);
    }
}

struct SegmentIterator<'a> {
    storage: &'a str,
    segments: std::vec::IntoIter<std::ops::Range<usize>>
}

impl<'a> Iterator for SegmentIterator<'a> {
    type Item = &'a str;

    fn next(&mut self) -> Option<Self::Item> {
        if let Some(range) = self.segments.next() {
            Some(&self.storage[range])
        } else {
            None
        }
    }
}

#[derive(Debug)]
pub(crate) enum PathSegment {
    /// `*`: match zero or more characters in a path segment
    Segment(Regex),
    /// `**`: match any number of path segments, including none
    AnyPathSegment,
}

#[cfg(test)]
mod test {
    #[test]
    fn glob_new() {
        use super::PathSegment;
        let glob = super::Glob::new("src/**/*.c").unwrap();

        assert!(glob.components.len() == 3);

        match &glob.components[0] {
            PathSegment::Segment(regex) => assert_eq!(regex.as_str(), r"src"),
            _ => panic!("expected a segment as first component")
        }

        match &glob.components[1] {
            PathSegment::AnyPathSegment => {},
            _ => panic!("expected any segment as second component")
        }

        match &glob.components[2] {
            PathSegment::Segment(regex) => assert_eq!(regex.as_str(), r".*\.c"),
            _ => panic!("expected a segment as third component")
        }
    }
}
