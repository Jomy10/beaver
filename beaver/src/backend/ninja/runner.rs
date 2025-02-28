use std::path::Path;
use std::process::Command;

use crate::{tools, BeaverError};

pub struct NinjaRunner<'a> {
    build_file: &'a Path,
    verbose: bool,
}

impl<'a> NinjaRunner<'a> {
    pub fn new(build_file: &'a Path, verbose: bool) -> Self {
        NinjaRunner {
            build_file,
            verbose,
        }
    }

    pub fn build<S: AsRef<str>>(&self, targets: &[S], base_dir: &Path) -> crate::Result<()> {
        let mut args = vec!["-f", self.build_file.to_str().expect("build file path is not UTF-8 encoded")];
        args.extend(targets.iter().map(|s| s.as_ref()));
        if self.verbose {
            args.push("-v");
        };
        let mut process = Command::new(tools::ninja.as_os_str())
            .args(args)
            .current_dir(base_dir)
            .spawn()
            .expect("Failed to start ninja");
        let exit_status = process.wait().expect("Command wasn't running");
        if !exit_status.success() {
            return Err(BeaverError::NonZeroExitStatus(exit_status));
        } else {
            return Ok(());
        }
    }
}
