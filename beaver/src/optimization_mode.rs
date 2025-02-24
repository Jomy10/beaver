#[derive(Copy, Clone, Debug)]
pub enum OptimizationMode {
    Debug,
    Release
}

use OptimizationMode::*;

impl std::fmt::Display for OptimizationMode {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Debug => f.write_str("debug"),
            Release => f.write_str("release"),
        }
    }
}

impl OptimizationMode {
    pub fn cflags(&self) -> &[&str] {
        match self {
            Debug => &["-g", "-O0"],
            Release => &["-O3", "-flto"],
        }
    }

    pub fn linker_flags(&self) -> &[&str] {
        match self {
            Debug => &["-O0"],
            Release => &["-O3", "-flto"]
        }
    }
}
