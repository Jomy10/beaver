use std::cmp::{Eq, PartialEq};

use crate::BeaverError;

pub trait TArtifactType: Sized + std::fmt::Display {
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
}

impl TArtifactType for LibraryArtifactType {
    fn parse(str: &str) -> crate::Result<LibraryArtifactType> {
        match str {
            "dynlib" => Ok(LibraryArtifactType::Dynlib),
            "staticlib" => Ok(LibraryArtifactType::Staticlib),
            "pkgconfig" | "pkg-config" | "pkgconf" | "pkg-conf" => Ok(LibraryArtifactType::PkgConfig),
            "framework" => Ok(LibraryArtifactType::Framework),
            "xcframework" => Ok(LibraryArtifactType::XCFramework),
            _ => Err(BeaverError::InvalidLibraryArtifactType(str.to_string())),
        }
    }
}

impl std::fmt::Display for LibraryArtifactType {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            LibraryArtifactType::Dynlib => f.write_str("dynlib"),
            LibraryArtifactType::Staticlib => f.write_str("staticlib"),
            LibraryArtifactType::PkgConfig => f.write_str("pkgconfig"),
            LibraryArtifactType::Framework => f.write_str("framework"),
            LibraryArtifactType::XCFramework => f.write_str("xcframework"),
            LibraryArtifactType::RustLib => f.write_str("rlib"),
            LibraryArtifactType::RustDynlib => f.write_str("rust_dynlib"),
        }
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
        match self {
            ExecutableArtifactType::Executable => f.write_str("exe"),
            ExecutableArtifactType::App => f.write_str("app"),
        }
    }
}

#[derive(Eq, PartialEq, Hash, Clone, Copy, Debug)]
pub enum CObjectType {
    Dynamic,
    Static
}
