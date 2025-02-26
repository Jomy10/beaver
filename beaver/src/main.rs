use std::{path::PathBuf, str::FromStr};

use beaver::target::parameters::{Files, Flags, Headers};
use beaver::target::{Dependency, Language, LibraryArtifactType};
use beaver::traits::{AnyTarget, MutableProject};
use beaver::{Beaver, OptimizationMode, target::c};
use beaver::project::beaver::Project as BeaverProject;

// example
fn main() {
    colog::init();

    let beaver = Beaver::new(Some(true), OptimizationMode::Debug);
    let project = BeaverProject::new(
        String::from("MyProject"),
        PathBuf::from("."),
        &PathBuf::from("build")
    ).unwrap();
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
        linker_flags: Vec::new(),
        artifacts: Vec::<LibraryArtifactType>::from([LibraryArtifactType::Staticlib]),
        dependencies: Vec::<Dependency>::new()
    });
    project.add_target(AnyTarget::Library(target.into())).unwrap();
    beaver.add_project(project.into()).unwrap();

    println!("{beaver}");

    beaver.create_build_file().unwrap();

    // let builder = Arc::new(RwLock::new(Box::new(NinjaBuilder::new())));
    // beaver.
}
