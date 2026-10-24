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

// see: https://users.rust-lang.org/t/concatenating-arrays/89538/8
macro_rules! concat_arrays {
    ( $a:expr, $b:expr $(,)?) => {{
        const fn must_be_arrays_of_same_type<T, const A: usize, const B: usize>(_: &[T; A], _: &[T; B]) {}
        const fn impossible_array<T, const X: usize, const C: usize>(_: &[T; X]) -> [T; C] { unreachable!() }
        const fn force_array<T, const C: usize>(a: [T; C]) -> [T; C] { a }
        #[repr(C)] // so they're in order
        struct TwoArrays<T, const A: usize, const B: usize>([T; A], [T; B]);

        let (a, b) = ($a, $b);
        must_be_arrays_of_same_type(&a, &b);
        if false {
            impossible_array(&a)
        } else if false {
            impossible_array(&b)
        } else {
            // SAFETY: `repr(C)` means that the two array fields are contiguous,
            // and they're arrays of the same type so the alignment is the same
            // and thus there's no padding.  The `if false` branches force the
            // type of this expression to be an array of the same type as the
            // input, and `transmute` only compiles if they're the same length,
            // so only the correct inferred output count `C` will work.
            let c = unsafe { ::std::mem::transmute(TwoArrays(a, b)) };
            force_array(c)
        }
    }}
}

impl ArtifactType {
    pub const fn as_str(&self) -> &'static str {
        match self {
            ArtifactType::Library(library_artifact_type) => library_artifact_type.as_str(),
            ArtifactType::Executable(executable_artifact_type) => executable_artifact_type.as_str(),
        }
    }

    pub fn parse(str: &str) -> crate::Result<ArtifactType> {
        match LibraryArtifactType::parse(str)
            .map(|aty| ArtifactType::Library(aty))
            .or_else(|_| ExecutableArtifactType::parse(str)
                .map(|aty| ArtifactType::Executable(aty))
            )
        {
            Ok(v) => Ok(v),
            Err(_) => Err(BeaverError::InvalidArtifactType(str.to_string())),
        }
    }

    pub const fn valid_identifiers() -> [&'static str; 10] {
        concat_arrays!(LibraryArtifactType::valid_identifiers(), ExecutableArtifactType::valid_identifiers())
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
    pub const fn as_str(&self) -> &'static str {
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

    /// Valid identifiers for `parse`
    pub const fn valid_identifiers() -> [&'static str; 8] {
        [
            LibraryArtifactType::Dynlib.as_str(),
            LibraryArtifactType::Staticlib.as_str(),
            LibraryArtifactType::PkgConfig.as_str(),
            LibraryArtifactType::Framework.as_str(),
            LibraryArtifactType::XCFramework.as_str(),
            LibraryArtifactType::RustLib.as_str(),
            LibraryArtifactType::RustDynlib.as_str(),
            LibraryArtifactType::JSLib.as_str(),
        ]
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
    pub const fn as_str(&self) -> &'static str {
        match self {
            ExecutableArtifactType::Executable => "exe",
            ExecutableArtifactType::App => "app",
        }
    }

    pub const fn valid_identifiers() -> [&'static str; 2] {
        [
            ExecutableArtifactType::Executable.as_str(),
            ExecutableArtifactType::App.as_str()
        ]
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
