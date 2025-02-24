use std::{path::PathBuf, str::FromStr};

use beaver::preface::traits::MutableProject;
use beaver::target::parameters::{Files, Flags, Headers};
use beaver::target::{Dependency, Language, LibraryArtifactType};
use beaver::{Beaver, OptimizationMode, preface::c};

fn main() {
    colog::init();

    let beaver = Beaver::new(true, OptimizationMode::Debug);
    let project = c::Project::new(
        String::from("MyProject"),
        PathBuf::from_str("./my_project").unwrap()
    );
    let target = c::Library::new_desc(c::LibraryDescriptor {
        name: "HelloWorld".to_string(),
        description: Some("A description of this package".to_string()),
        homepage: None,
        version: None,
        license: None,
        language: Language::C,
        sources: Files::from_pat("src/**/*.rs").unwrap(),
        cflags: Flags::new(vec![String::from("-DDEBUG")], Vec::new()),
        headers: Headers::new(vec![PathBuf::from_str("include").unwrap()], Vec::new()),
        linker_flags: Flags::new(Vec::new(), Vec::new()),
        artifacts: Vec::<LibraryArtifactType>::from([LibraryArtifactType::Staticlib]),
        dependencies: Vec::<Dependency>::new()
    });
    project.add_target(Box::new(target)).unwrap();
    beaver.add_project(Box::new(project)).unwrap();

    println!("{beaver}");
}
