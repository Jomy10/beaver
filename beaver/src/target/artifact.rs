use std::cmp::{Eq, PartialEq};

#[derive(Eq, PartialEq, Hash, Clone, Copy)]
pub enum ArtifactType {
    Library(LibraryArtifactType),
    Executable(ExecutableArtifactType),
}

#[derive(Eq, PartialEq, Hash, Clone, Copy)]
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

#[derive(Eq, PartialEq, Hash, Clone, Copy)]
pub enum ExecutableArtifactType {
    Executable,
    /// a macOS app
    App
}

#[derive(Eq, PartialEq, Hash, Clone, Copy)]
pub enum CObjectType {
    Dynamic,
    Static
}
