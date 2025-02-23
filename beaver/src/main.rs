use std::{path::PathBuf, str::FromStr};

use beaver::{Beaver, OptimizationMode, preface::c};

fn main() {
    colog::init();

    let beaver = Beaver::new(true, OptimizationMode::Debug);
    let project = c::Project::new(
        String::from("MyProject"),
        PathBuf::from_str("./my_project").unwrap()
    );
    // let target = c::Library::new(

    // );
    // project.add_target(Box::new(target));
    beaver.add_project(Box::new(project)).unwrap();

    println!("{beaver}");
}
