pub mod c_project;
pub mod dependencies;
pub mod multi_project;
pub mod cmake;
pub mod pre_phase_hooks;
pub mod cargo;
pub mod objc;
pub mod spm;
pub mod arguments;

pub(crate) fn example_dir_no_clean(example: &str) -> std::path::PathBuf {
    std::env::current_dir().unwrap()
        .join("../examples")
        .join(example)
}

pub(crate) fn example_dir(example: &str) -> std::path::PathBuf {
    let dir = example_dir_no_clean(example);

    let mut proc = std::process::Command::new(crate::beaver())
        .args(["clean"])
        .current_dir(&dir)
        .spawn()
        .unwrap();

    proc.wait().unwrap();

    return dir;
}
