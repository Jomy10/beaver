use std::{path::PathBuf, str::FromStr};

use beaver::preface::traits::MutableProject;
use beaver::target::parameters::{Files, Flags, Headers};
use beaver::target::{Dependency, Language, LibraryArtifactType};
use beaver::{Beaver, OptimizationMode, preface::c};

/// Test adding a project and a target
#[test]
fn adding() {
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

    let projects = beaver.projects().unwrap();
    assert_eq!(projects.len(), 1);

    let bproject = projects.first().unwrap();

    assert_eq!(bproject.name(), "MyProject".to_string());
    assert_eq!(bproject.id(), Some(0));

    let targets = bproject.targets().unwrap();
    assert_eq!(targets.len(), 1);

    let btarget = targets.first().unwrap();
    assert_eq!(btarget.name(), "HelloWorld".to_string());
    assert_eq!(btarget.id(), Some(0));
    assert_eq!(btarget.project_id(), Some(0));
}
