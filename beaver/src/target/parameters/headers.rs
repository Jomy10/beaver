use std::path::{Path, PathBuf};

#[derive(Debug)]
pub struct Headers {
    public: Vec<PathBuf>,
    private: Vec<PathBuf>,
}

impl Headers {
    pub fn new(public: Vec<PathBuf>, private: Vec<PathBuf>) -> Headers {
        Headers { public, private }
    }

    pub(crate) fn public<'a>(&'a self, relative_to_path: &'a Path) -> impl Iterator<Item = PathBuf> + 'a {
        self.public.iter().map(|path| {
            relative_to_path.join(path)
        })
    }

    pub(crate) fn private<'a>(&'a self, relative_to_path: &'a Path) -> impl Iterator<Item = PathBuf> + 'a {
        self.private.iter().map(|path| {
            relative_to_path.join(path)
        })
    }
}
