use std::cmp::{Eq, PartialEq};

#[derive(Eq, PartialEq, Hash, Clone, Copy, Debug)]
pub enum ArtifactType {
    Library(LibraryArtifactType),
    Executable(ExecutableArtifactType),
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
}

impl std::fmt::Display for LibraryArtifactType {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            LibraryArtifactType::Dynlib => f.write_str("dynlib"),
            LibraryArtifactType::Staticlib => f.write_str("staticlib"),
            LibraryArtifactType::PkgConfig => f.write_str("pkgconfig"),
            LibraryArtifactType::Framework => f.write_str("framework"),
            LibraryArtifactType::XCFramework => f.write_str("xcframework"),
        }
    }
}

#[derive(Eq, PartialEq, Hash, Clone, Copy, Debug)]
pub enum ExecutableArtifactType {
    Executable,
    /// a macOS app
    App
}

#[derive(Eq, PartialEq, Hash, Clone, Copy, Debug)]
pub enum CObjectType {
    Dynamic,
    Static
}
