use crate::target::parameters::{DefaultArgument, Files, Flags, Headers};
use crate::target::{Dependency, Language, Version};

pub struct TargetDescriptor<ArtifactType> {
    pub name: String,
    pub description: Option<String>,
    pub homepage: Option<url::Url>,
    pub version: Option<Version>,
    pub license: Option<String>,
    pub language: Language,
    pub sources: Files,
    pub cflags: Flags,
    pub headers: Headers,
    pub linker_flags: Vec<String>,
    pub artifacts: DefaultArgument<Vec<ArtifactType>>,
    pub dependencies: Vec<Dependency>
}
