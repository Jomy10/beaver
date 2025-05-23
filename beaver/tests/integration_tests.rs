use std::{path::PathBuf, str::FromStr};

use beaver::target::parameters::{DefaultArgument, Files, Flags, Headers};
use beaver::target::{Dependency, Language, LibraryArtifactType};
use beaver::project::beaver::Project as BeaverProject;
use beaver::traits::{AnyTarget, MutableProject, Project, Target};
use beaver::{Beaver, OptimizationMode, target::c};
use target_lexicon::Triple;

/// Test adding a project and a target
#[test]
fn adding() {
    let tmpdir = tempdir::TempDir::new("be.jonaseveraert.beaver.tests.beaver.adding").unwrap();
    let tmpdir = tmpdir.into_path();

    dbg!(&tmpdir);

    let beaver = Beaver::new(Some(true), OptimizationMode::Debug, true, false, Triple::host()).unwrap();
    beaver.set_build_dir(tmpdir.join("build")).unwrap();
    let project = BeaverProject::new(
        String::from("MyProject"),
        tmpdir.clone(),
        beaver.get_build_dir().unwrap()
    ).unwrap();
    let target = c::Library::new_desc(c::TargetDescriptor {
        name: "HelloWorld".to_string(),
        description: Some("A description of this package".to_string()),
        homepage: None,
        version: None,
        license: None,
        language: Language::C,
        sources: Files::from_pat("src/**/*.rs", project.base_dir()).unwrap(),
        cflags: Flags::new(vec![String::from("-DDEBUG")], Vec::new()),
        headers: Headers::new(vec![PathBuf::from_str("include").unwrap()], Vec::new()),
        linker_flags: Vec::new(),
        artifacts: DefaultArgument::Some(Vec::<LibraryArtifactType>::from([LibraryArtifactType::Staticlib])),
        dependencies: Vec::<Dependency>::new(),
        settings: Vec::new()
    }).unwrap();
    project.add_target(AnyTarget::Library(target.into())).unwrap();
    beaver.add_project(project).unwrap();

    println!("{beaver}");

    let projects = beaver.projects().unwrap();
    assert_eq!(projects.len(), 1);

    let bproject = projects.first().unwrap();

    assert_eq!(bproject.name(), "MyProject".to_string());
    assert_eq!(bproject.id(), Some(0));
    assert_eq!(beaver.current_project_index(), bproject.id());

    let targets = bproject.targets().unwrap();
    assert_eq!(targets.len(), 1);

    let btarget = targets.first().unwrap();
    assert_eq!(btarget.name(), "HelloWorld".to_string());
    assert_eq!(btarget.id(), Some(0));
    assert_eq!(btarget.project_id(), Some(0));
}
