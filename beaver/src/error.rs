use std::io;
use std::path::PathBuf;
use std::process::ExitStatus;

use target_lexicon::OperatingSystem;

#[derive(thiserror::Error)]
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
    #[error("PathDiffFailed")]
    PathDiffFailed,

    // Dependency Resolution //
    #[error("No target named {0} in project {1}")]
    NoTargetNamed(String, String),
    #[error("No project named {0}")]
    NoProjectNamed(String),
    #[error("Library `{0}` not found with pkgconfig")]
    PkgconfigNotFound(String),
    #[error("Malformed arguments received from pkgconfig: {0}")]
    PkgconfigMalformed(String),
    #[error("Malformed version requirement for pkgconfig dependency. Valid requirements are for example `>=1.3.4`, `=1.3`, `<=5`")]
    PkgconfigMalformedVersionRequirement(String),

    // Debug fmt //
    #[error("")]
    DebugBufferWriteError(std::fmt::Error),

    // General Errors //
    #[error("There are no projects defined")]
    NoProjects,
    #[error("Project `{0}` is not mutable")]
    ProjectNotMutable(String),
    #[error("More than one executable is present in project {project}. Specify the target to run (targets in this project are {})", targets.join(" "))]
    ManyExecutable {
        project: String,
        targets: Vec<String>
    },
    #[error("No executable target found in project {0}")]
    NoExecutable(String),

    #[error("Failed to lock: {0}")]
    LockError(String),
    #[error("IO Error: {0}")]
    IOError(#[from] std::io::Error),
    #[error("{0}")]
    AnyError(String),
    #[error("A child process exited with a non-zero exit code: {0}")]
    NonZeroExitStatus(ExitStatus),

    // Command Line //
    #[error("Invalid {name} `{got}` (valid values are {})", expected_values.iter().map(|v| format!("`{}`", v)).collect::<Vec<String>>().join(", "))]
    TryFromStringError {
        name: String,
        got: String,
        expected_values: Vec<String>,
    },
    #[error("Invalid library artifact type `{0}`. Valid artifacts are `dynlib`, `staticlib`, `pkgconfig`, `framework` and `xcframework`")]
    InvalidLibraryArtifactType(String),
    #[error("Invalid executable artifact type `{0}`. Valid artifacts are `executable` and `app`")]
    InvalidExecutableArtifactType(String),
}

pub type Result<Success> = std::result::Result<Success, BeaverError>;

impl std::fmt::Debug for BeaverError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        // Automatically get propper error messages from main function returning a result
        std::fmt::Display::fmt(self, f)
    }
}
