use std::ffi::{self, OsString};
use std::str::FromStr;

use crate::BeaverError;

#[derive(Copy, Clone, Debug, PartialEq, Eq)]
pub enum OptimizationMode {
    Debug,
    Release
}

use OptimizationMode::*;

impl OptimizationMode {
    pub fn cflags(&self) -> &[&str] {
        match self {
            Debug => &["-g", "-O0"],
            Release => &["-O3", "-flto", "-DNDEBUG"],
        }
    }

    pub fn linker_flags(&self) -> &[&str] {
        match self {
            Debug => &["-O0"],
            Release => &["-O3", "-flto"]
        }
    }

    pub fn cargo_flags(&self) -> &[&str] {
        match self {
            Debug => &[],
            Release => &["--release"],
        }
    }

    pub fn cmake_name(&self) -> &'static str {
        match self {
            Debug => "Debug",
            Release => "Release",
        }
    }

    pub fn cargo_name(&self) -> &'static str {
        match self {
            Debug => "debug",
            Release => "release",
        }
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
