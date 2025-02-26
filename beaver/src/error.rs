use std::io;
use std::path::PathBuf;

use target_lexicon::OperatingSystem;
use thiserror::Error;

#[derive(Error, Debug)]
pub enum BeaverError {
    // Set Build Dir //
    #[error("Can't set the build directory when a project is alreadt defined")]
    SetBuildDirAfterAddProject,

    // Project access //
    #[error("Couldn't lock projects for writing: {0}")]
    ProjectsWriteError(String),
    #[error("Couldn't lock projects for reading: {0}")]
    ProjectsReadError(String),

    // Target Access //
    #[error("Couldn't lock targets for writing: {0}")]
    TargetsWriteError(String),
    #[error("Couldn't lock targets for reading: {0}")]
    TargetsReadError(String),

    // Target Triple //
    #[error("Unknown target OS `{0}`")]
    UnknownTargetOS(OperatingSystem),
    #[error("Target OS `{0}` doesn't support dynamic libraries")]
    TargetDoesntSupportDynamicLibraries(OperatingSystem),
    #[error("Target OS `{0}` doesn't support frameworks")]
    TargetDoesntSupportFrameworks(OperatingSystem),

    // Arguments //
    #[error("Invalid glob pattern `{0}`: {1}")]
    GlobPatternError(String, glob::GlobError),
    #[error("Error occurred resolving glob: {0}")]
    GlobIterationError(#[from] glob::GlobIterationError),

    // BackendBuilder //
    #[error("Couldn't lock BackendBuilder: {0}")]
    BackendLockError(String),
    #[error("Couldn't write to BackendBuilder buffer: {0}")]
    BufferWriteError(String),
    #[error("Error writing build file: {0}")]
    BuildFileWriteError(io::Error),

    // Project Validation //
    #[error("Base path {path} of project {project} doesn't exist")]
    ProjectPathDoesntExist { project: String, path: PathBuf },

    // Command Line //
    #[error("Invalid {name} `{got}` (valid values are {})", expected_values.iter().map(|v| format!("`{}`", v)).collect::<Vec<String>>().join(", "))]
    TryFromStringError {
        name: String,
        got: String,
        expected_values: Vec<String>,
    },
}

pub type Result<Success> = std::result::Result<Success, BeaverError>;
