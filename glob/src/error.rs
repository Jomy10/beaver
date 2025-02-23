use thiserror::Error;

#[derive(Error, Debug)]
pub enum GlobError {
    #[error("Invalid escape sequence `{0}`")]
    InvalidEscape(String)
}

#[derive(Error, Debug)]
pub enum GlobIterationError {
    #[error("Couldn't read directory: {0}")]
    ReadDirError(#[from] std::io::Error),
    #[error("The base path of `files` should be a directory")]
    BasePathNotDirectory,
}
