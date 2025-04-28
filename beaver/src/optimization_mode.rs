use std::ffi::{self, OsString};
use std::str::FromStr;

use lazy_static::lazy_static;

use crate::tools::{self, CCVersion};
use crate::BeaverError;

#[derive(Copy, Clone, Debug, PartialEq, Eq)]
pub enum OptimizationMode {
    Debug,
    Release
    // TODO:
    // - Size (-Os)
    // - Fast (-Ofast)
    // - MinimalSize (-Oz)
}

use OptimizationMode::*;

lazy_static! {
    static ref cflags_release: Vec<&'static str> = {
        let mut v = ["-O3", "-flto", "-DNDEBUG"].to_vec();
        match &*tools::cc_version {
            CCVersion::Clang(ver) => if ver.major >= 18 { v.push("-ffat-lto-objects") },
            CCVersion::Gcc(_) => v.push("-ffat-lto-objects"),
            _ => {}
        }
        return v;
    };

    static ref linker_flags_release: Vec<&'static str> = {
        let mut v = ["-O3", "-flto"].to_vec();
        match &*tools::cc_version {
            CCVersion::Clang(ver) => if ver.major >= 18 { v.push("-ffat-lto-objects") },
            CCVersion::Gcc(_) => v.push("-ffat-lto-objects"),
            _ => {}
        }
        return v;
    };
}

/// see: [Options That Control Optimization](https://gcc.gnu.org/onlinedocs/gcc/Optimize-Options.html)
impl OptimizationMode {
    // Flags //
    pub fn cflags(&self) -> &[&str] {
        match self {
            Debug => &["-g", "-O0"],
            Release => cflags_release.as_slice(),
        }
    }

    pub fn linker_flags(&self) -> &[&str] {
        match self {
            Debug => &["-g", "-O0"],
            Release => linker_flags_release.as_slice()
        }
    }

    pub fn cargo_flags(&self) -> &[&str] {
        match self {
            Debug => &[],
            Release => &["--release"],
        }
    }

    // Names //
    pub fn cmake_name(&self) -> &'static str {
        match self {
            Debug => "Debug",
            Release => "Release",
        }
    }

    fn lowercase_name(&self) -> &'static str {
        match self {
            Debug => "debug",
            Release => "release",
        }
    }

    pub fn cargo_name(&self) -> &'static str {
        self.lowercase_name()
    }

    pub fn swift_name(&self) -> &'static str {
        self.lowercase_name()
    }
}

impl std::fmt::Display for OptimizationMode {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Debug => f.write_str("debug"),
            Release => f.write_str("release"),
        }
    }
}

impl TryFrom<&str> for OptimizationMode {
    type Error = BeaverError;

    fn try_from(value: &str) -> Result<Self, Self::Error> {
        match value.to_lowercase().as_str() {
            "debug" => Ok(Debug),
            "release" => Ok(Release),
            _ => Err(BeaverError::TryFromStringError {
                name: "optimization mode".to_string(),
                got: value.to_string(),
                expected_values: vec!["debug".to_string(), "release".to_string()]
            })
        }
    }
}

impl Into<String> for OptimizationMode {
    fn into(self) -> String {
        match self {
            Debug => "debug".to_string(),
            Release => "release".to_string(),
        }
    }
}

impl Into<ffi::OsString> for OptimizationMode {
    fn into(self) -> OsString {
            match self {
                Debug => OsString::from_str("debug").unwrap(),
                Release => OsString::from_str("release").unwrap(),
            }
        }
}

impl Default for OptimizationMode {
    fn default() -> Self {
        Self::Debug
    }
}
