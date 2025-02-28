#[derive(Debug)]
pub enum Version {
    Any(String),
    Semver(semver::Version),
}

impl Version {
    pub fn parse(s: &str) -> Self {
        match semver::Version::parse(s) {
            Ok(semver) => Self::Semver(semver),
            Err(_) => Self::Any(s.to_string())
        }
    }
}
