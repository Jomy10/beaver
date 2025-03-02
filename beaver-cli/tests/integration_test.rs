//! test the executable

use std::path::Path;

mod examples;

pub(crate) fn beaver() -> std::path::PathBuf {
    let mut path = std::env::current_dir().unwrap()
        .join("../target");
    #[cfg(debug_assertions)]
    {
        path = path.join("debug");
    }
    #[cfg(not(debug_assertions))]
    {
        path = path.join("release");
    }
    path.join("beaver-cli")
}

pub(crate) fn run<'a>(dir: &Path, stdout: &'a mut String) -> (impl Iterator<Item = &'a str>, Option<i32>) {
    let output = ::std::process::Command::new(crate::beaver())
        .args(&["run"])
        .current_dir(dir)
        .output()
        .unwrap();

    *stdout = String::from_utf8(output.stdout).unwrap();
    let components = stdout.split("\n").filter(|val| *val != "");
    let mut iter = components.into_iter().peekable();
    while let Some(val) = iter.peek() {
        let br = val.starts_with("Cleaning...");
        _ = iter.next();
        if br { break; }
    }

    (iter, output.status.code())
}
