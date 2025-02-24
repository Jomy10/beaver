use super::LibraryArtifactType;

#[derive(Eq, PartialEq, Hash)]
pub enum Dependency {
    Library(LibraryTargetDependency),
}

#[derive(Eq, PartialEq, Hash)]
pub struct TargetRef {
    pub target: usize,
    pub project: usize,
}

#[derive(Eq, PartialEq, Hash)]
pub struct LibraryTargetDependency {
    target: TargetRef,
    artifact: LibraryArtifactType,
}
