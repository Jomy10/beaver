pub mod c_project;
pub mod dependencies;
pub mod multi_project;
pub mod cmake;

pub(crate) fn example_dir(example: &str) -> std::path::PathBuf {
    std::env::current_dir().unwrap()
        .join("../examples")
        .join(example)
}
