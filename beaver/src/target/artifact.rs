use std::cmp::{Eq, PartialEq};

use crate::BeaverError;

pub trait TArtifactType: Sized + std::fmt::Display + Into<ArtifactType> + Copy + Clone {
    fn parse(str: &str) -> crate::Result<Self>;
}

#[derive(Eq, PartialEq, Hash, Clone, Copy, Debug)]
pub enum ArtifactType {
    Library(LibraryArtifactType),
    Executable(ExecutableArtifactType),
}

impl ArtifactType {
    pub fn as_library(&self) -> Option<LibraryArtifactType> {
        match self {
            ArtifactType::Library(art) => Some(*art),
            _ => None
        }
    }

    pub fn as_executable(&self) -> Option<ExecutableArtifactType> {
        match self {
            ArtifactType::Executable(art) => Some(*art),
            _ => None
        }
    }
}

impl std::fmt::Display for ArtifactType {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            ArtifactType::Library(library_artifact_type) => library_artifact_type.fmt(f),
            ArtifactType::Executable(executable_artifact_type) => executable_artifact_type.fmt(f),
        }
    }
}

impl ArtifactType {
    pub fn as_str(&self) -> &'static str {
        match self {
            ArtifactType::Library(library_artifact_type) => library_artifact_type.as_str(),
            ArtifactType::Executable(executable_artifact_type) => executable_artifact_type.as_str(),
        }
    }
}

#[derive(Eq, PartialEq, Hash, Clone, Copy, Debug)]
pub enum LibraryArtifactType {
    /// A dynamic library callable through C convention
    Dynlib,
    Staticlib,
    PkgConfig,
    // framework/xcframework: see https://bitmountn.com/difference-between-framework-and-xcframework-in-ios/
    /// macOS framework
    Framework,
    XCFramework,

    // Rust //
    /// rlib: A static rust library
    RustLib,
    /// dylib: A dynamic rust library
    RustDynlib,

    // Emscripten //
    JSLib,
}

impl TArtifactType for LibraryArtifactType {
    fn parse(str: &str) -> crate::Result<LibraryArtifactType> {
        match str {
            "dynlib" => Ok(LibraryArtifactType::Dynlib),
            "staticlib" | "static" => Ok(LibraryArtifactType::Staticlib),
            "pkgconfig" | "pkg-config" | "pkgconf" | "pkg-conf" => Ok(LibraryArtifactType::PkgConfig),
            "framework" => Ok(LibraryArtifactType::Framework),
            "xcframework" => Ok(LibraryArtifactType::XCFramework),
            "jslib" => Ok(LibraryArtifactType::JSLib),
            _ => Err(BeaverError::InvalidLibraryArtifactType(str.to_string())),
        }
    }
}

impl std::fmt::Display for LibraryArtifactType {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str(self.as_str())
    }
}

impl LibraryArtifactType {
    pub fn as_str(&self) -> &'static str {
        match self {
            LibraryArtifactType::Dynlib => "dynlib",
            LibraryArtifactType::Staticlib => "staticlib",
            LibraryArtifactType::PkgConfig => "pkgconfig",
            LibraryArtifactType::Framework => "framework",
            LibraryArtifactType::XCFramework => "xcframework",
            LibraryArtifactType::RustLib => "rlib",
            LibraryArtifactType::RustDynlib => "rust_dynlib",
            LibraryArtifactType::JSLib => "jslib",
        }
    }
}

impl Into<ArtifactType> for LibraryArtifactType {
    fn into(self) -> ArtifactType {
        ArtifactType::Library(self)
    }
}

#[derive(Eq, PartialEq, Hash, Clone, Copy, Debug)]
pub enum ExecutableArtifactType {
    Executable,
    /// a macOS app
    App
}

impl TArtifactType for ExecutableArtifactType {
    fn parse(str: &str) -> crate::Result<ExecutableArtifactType> {
        match str {
            "exe" | "exec" | "executable" => Ok(ExecutableArtifactType::Executable),
            "app" => Ok(ExecutableArtifactType::App),
            _ => Err(BeaverError::InvalidExecutableArtifactType(str.to_string())),
        }
    }
}

impl std::fmt::Display for ExecutableArtifactType {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str(self.as_str())
    }
}

impl ExecutableArtifactType {
    pub fn as_str(&self) -> &'static str {
        match self {
            ExecutableArtifactType::Executable => "exe",
            ExecutableArtifactType::App => "app",
        }
    }
}

impl Into<ArtifactType> for ExecutableArtifactType {
    fn into(self) -> ArtifactType {
        ArtifactType::Executable(self)
    }
}

#[derive(Eq, PartialEq, Hash, Clone, Copy, Debug)]
pub enum CObjectType {
    Dynamic,
    Static
}
