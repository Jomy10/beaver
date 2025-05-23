use std::backtrace::BacktraceStatus;
use std::ffi::{CStr, OsString};
use std::io;
use std::path::PathBuf;
use std::process::ExitStatus;
use std::string::FromUtf8Error;
use std::time::{SystemTimeError, TryFromFloatSecsError};

use target_lexicon::OperatingSystem;
use utils::str::OsStrConversionError;

use crate::target::{self, ArtifactType, Language};

#[derive(thiserror::Error)]
pub enum BeaverError {
    // Set Build Dir //
    #[error("Can't set the build directory when a project is alreadt defined")]
    SetBuildDirAfterAddProject,
    #[error("Beaver was already finalized and cannot be mutated")]
    AlreadyFinalized,
    #[error("Invalid status {0}")]
    InvalidState(u8),
    #[error("Invalid phase `{0}`")]
    InvalidPhase(String),
    #[error("An unrecoverable error occurred earlier and `Beaver` cannot be used further")]
    UnrecoverableError,

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

    // Run error //
    #[error("No executable artifact found in target '{0}'")]
    NoExecutableArtifact(String),

    // Target Triple //
    #[error("Unknown target OS `{0}`")]
    UnknownTargetOS(OperatingSystem),
    #[error("Target OS `{0}` doesn't support dynamic libraries")]
    TargetDoesntSupportDynamicLibraries(OperatingSystem),
    #[error("Target OS `{0}` doesn't support frameworks")]
    TargetDoesntSupportFrameworks(OperatingSystem),
    #[error("Target OS `{0}` doesn't support javascript library")]
    TargetDoesntSupportJSLib(OperatingSystem),

    // Arguments //
    // #[error("Invalid glob pattern `{0}`: {1}")]
    // GlobPatternError(String, glob::GlobError),
    // #[error("Error occurred resolving glob: {0}")]
    // GlobIterationError(#[from] glob::GlobIterationError),
    #[error("Glob error: {0}")]
    GlobError(#[from] globwalk::GlobError),
    #[error("Error while walking glob: {0}")]
    GlobWalkError(#[from] globwalk::WalkError),

    // BackendBuilder //
    #[error("Couldn't lock BackendBuilder: {0}")]
    BackendLockError(String),
    #[error("Couldn't write to BackendBuilder buffer: {0}")]
    BufferWriteError(String),
    #[error("Error writing build file: {0}")]
    BuildFileWriteError(io::Error),

    // Symlink //
    #[error("Couldn't create symlink {1} -> {2}: {0}")]
    SymlinkCreationError(io::Error, PathBuf, PathBuf),
    #[error("Couldn't create symlink because a file or directory already exists at the location and it's not a symlink: {0}")]
    SymlinkCreationExists(PathBuf),

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
    #[error("No project with id {0}")]
    NoProjectWithId(usize),
    #[error("Library `{0}` not found with pkgconfig")]
    PkgconfigNotFound(String),
    #[error("Malformed arguments received from pkgconfig: {0}")]
    PkgconfigMalformed(String),
    #[error("Malformed version requirement for pkgconfig dependency. Valid requirements are for example `>=1.3.4`, `=1.3`, `<=5`")]
    PkgconfigMalformedVersionRequirement(String),

    #[error("Error parsing pkg-config file '{0}': {1}")]
    PkgconfigParsingError(PathBuf, pkgconfig_parser::Error),

    // Debug fmt //
    #[error("DebugBufferWriteError: {0}")]
    DebugBufferWriteError(std::fmt::Error),

    // Cache //
    // #[error("SQL Error: {0}")]
    // SQLError(#[from] ormlite::SqlxError),
    // #[error("ORMLite Error: {0}")]
    // ORMLiteError(String),
    #[error("Error opening file to be cached {0}: {1}")]
    OpeningFileToBeCached(String, io::Error),
    #[error("System time conversion error")]
    SystemTimeConversionError,
    #[error(transparent)]
    TryFromFloatSecsError(#[from] TryFromFloatSecsError),
    #[error("Nul terminator in filename or context {0} - {1}")]
    NulTerminatorInFile(String, String),
    #[error(transparent)]
    SledError(#[from] sled::Error),
    #[error("Unknown file context {0}")]
    FileContextUnknown(String),

    // Commands //
    #[error("Command '{0}' exists")]
    CommandExists(String),
    #[error("No command exists with the name '{0}'")]
    NoCommand(String),

    // Targets //
    #[error("Language '{0:?}' cannot be used for a {1} target")]
    InvalidLanguage(Language, &'static str),
    #[error("Language '{0:?}' cannot be used for a {1} artifact")]
    InvalidLanguageForArtifact(Language, &'static str),
    #[error("Artifact '{0:?}' cannot be used for a {1} target")]
    InvalidArtifact(ArtifactType, &'static str),
    #[error("Target {1} does not have an artifact of type {0:?}")]
    NoArtifact(ArtifactType, String),
    /// Custom targets have build commands
    #[error("Target {0} has no build command")]
    TargetHasNoBuildCommand(String),

    #[error("Error while parsing C setting '{}': {:?}", .0, .1)]
    CSettingParseError(String, target::c::SettingParseError),

    // Custom //
    #[error("Invalid pipe command {:x?}", .0)]
    InvalidPipeCommand(u8),
    #[error("Target {0} has no build command")]
    TargetNoBuildCommand(String),

    // CMake //
    #[error("CMake failed")]
    CMakeFailed,
    // #[error("Failed to get reply from CMake")]
    // CMakeNoReply,
    #[error("Failed to read CMake reply: 0")]
    CMakeReplyError(#[from] cmake_file_api::reply::ReaderError),
    // #[error("Error deserializing CMake query reply json: {0}")]
    // CMakeDeserializeError(serde_json::Error),
    #[error("Missing CMake configuration {0}")]
    CMakeMissingConfig(&'static str),
    #[error("Unknown language from CLang: {0}")]
    CMakeUnknownLanguage(String),
    #[error("CMake target with id '{0}' not found")]
    NoCMakeTarget(String),

    // Cargo //
    #[error("CargoManifestError: {0}")]
    CargoManifestError(#[from] cargo_manifest::Error),

    // SPM //
    #[error("SwiftManifestError: {0}")]
    SwiftManifestError(#[from] spm_manifest::Error),
    #[error("Not a swift package path: {0}")]
    NotASwiftPackagePath(PathBuf),

    // Meson //
    #[error("Meson failed to setup")]
    MesonFailed,
    #[error("Provided pkgconfig path does not exist {}", .0.display())]
    InvalidPkgConfigPath(PathBuf),

    // General Errors //
    #[error("There are no projects defined")]
    NoProjects,
    #[error("Project `{0}` is not mutable")]
    ProjectNotMutable(String),
    #[error("Project `{0}`'s targets are not mutable")]
    ProjectNotTargetMutable(String),
    #[error("Project with name '{0}' already imported")]
    ProjectAlreadyExists(String, usize),
    #[error("More than one executable is present in project {project}. Specify the target to run (targets in this project are {})", targets.join(" "))]
    ManyExecutable {
        project: String,
        targets: Vec<String>
    },
    #[error("No executable target found in project {0}")]
    NoExecutable(String),
    #[error("OS String is not UTf-8")]
    NonUTF8OsStr(OsString),
    #[error(transparent)]
    FromUTF8Error(#[from] FromUtf8Error),
    #[error("{0}")]
    SystemTimeError(#[from] SystemTimeError),
    #[error(transparent)]
    OsStringConversionError(#[from] OsStrConversionError),
    #[error("Error from libc: {}", unsafe { CStr::from_ptr(libc::strerror(*.0)) }.to_str().unwrap())]
    LibcError(i32),

    #[error("Failed to lock: {0}")]
    LockError(String),
    #[error("IO Error: {}{}", .0, if .1.status() == BacktraceStatus::Captured { format!("\n{}", .1) } else { String::from("") })]
    IOError(#[from] std::io::Error, std::backtrace::Backtrace),
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
