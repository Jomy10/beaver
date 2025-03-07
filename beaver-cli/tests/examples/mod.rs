pub mod c_project;
pub mod dependencies;
pub mod multi_project;
pub mod cmake;
pub mod pre_phase_hooks;

pub(crate) fn example_dir(example: &str) -> std::path::PathBuf {
    std::env::current_dir().unwrap()
        .join("../examples")
        .join(example)
}
