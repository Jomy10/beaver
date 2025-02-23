use target_lexicon::OperatingSystem;
use thiserror::Error;

#[derive(Error, Debug)]
pub enum BeaverError {
    // Project access //
    #[error("Couldn't lock projects for writing")]
    ProjectsWriteError(String),

    // Target Access //
    #[error("Couldn't lock targets for writing")]
    TargetsWriteError(String),
    #[error("Couldn't lock targets for reading")]
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
}

pub type Result<Success> = std::result::Result<Success, BeaverError>;
