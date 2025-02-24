#[derive(Debug)]
pub enum Version {
    Any(String),
    Semver(semver::Version),
}
