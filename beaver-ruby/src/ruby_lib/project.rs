use std::path::PathBuf;

use beaver::project;
use beaver::traits::AnyProject;

use crate::{BeaverRubyError, RBCONTEXT};

use super::project_accessor::ProjectAccessor;
use super::Arg;

fn define_project(args: magnus::RHash) -> Result<ProjectAccessor, magnus::Error> {
    let context = unsafe { &*RBCONTEXT.assume_init() };

    let mut name: Arg<String> = Arg::new("name");
    let mut base_dir: Arg<PathBuf> = Arg::new("base_dir");

    args.foreach(|key: magnus::Symbol, value: magnus::Value| {
        match key.name()?.as_ref() {
            "name" => {
                let name_value = magnus::RString::from_value(value);
                let value = if let Some(str) = name_value {
                    str.to_string()
                } else {
                    if let Some(symbol) = magnus::Symbol::from_value(value) {
                        Ok(symbol.to_string())
                    } else {
                        Err(BeaverRubyError::IncompatibleType(value, "String or Symbol").into())
                    }
                }?;
                name.set(value)?;
            },
            "base_dir" => {
                let value = match magnus::RString::from_value(value){
                    Some(str) => str.to_string(),
                    None => Err(BeaverRubyError::IncompatibleType(value, "String").into())
                }?;
                base_dir.set(PathBuf::from(value))?;
            },
            _ => {return Err(BeaverRubyError::InvalidKey(key.to_string()).into());}
        }

        Ok(magnus::r_hash::ForEach::Continue)
    })?;

    let curdir = std::env::current_dir().map_err(|err| BeaverRubyError::from(err))?;

    let project: AnyProject = AnyProject::Beaver(project::beaver::Project::new(
        name.get()?,
        base_dir.get_opt().unwrap_or(curdir),
        &context.get_build_dir().map_err(|err| BeaverRubyError::from(err))?
    ).map_err(|err| BeaverRubyError::from(err))?);

    let project_index = context.add_project(project).map_err(|err| BeaverRubyError::from(err))?;

    let project_accessor = ProjectAccessor { id: project_index };

    Ok(project_accessor)
}

// TODO: optional splat -> cmake flags
fn import_cmake(dir: String) -> Result<(), magnus::Error> {
    let context = unsafe { &*RBCONTEXT.assume_init() };
    project::cmake::import(&PathBuf::from(dir), &[], &context)
        .map_err(|err| BeaverRubyError::from(err).into())
}

// TODO: optional splat -> cargo flags
fn import_cargo(dir: String) -> Result<(), magnus::Error> {
    let context = unsafe { &*RBCONTEXT.assume_init() };
    project::cargo::import(&PathBuf::from(dir), vec![], &context)
        .map_err(|err| BeaverRubyError::from(err).into())
}

pub fn register(ruby: &magnus::Ruby) -> crate::Result<()> {
    ruby.define_global_function("Project", magnus::function!(define_project, 1));
    ruby.define_global_function("import_cmake", magnus::function!(import_cmake, 1));
    ruby.define_global_function("import_cargo", magnus::function!(import_cargo, 1));

    Ok(())
}
