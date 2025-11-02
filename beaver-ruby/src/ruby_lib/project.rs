use std::path::PathBuf;

use beaver::project;
use beaver::traits::AnyProject;
use magnus::value::ReprValue;

use crate::{BeaverRubyError, CTX};

use super::project_accessor::ProjectAccessor;
use super::Arg;

fn define_project(ruby: &magnus::Ruby, args: magnus::RHash) -> Result<ProjectAccessor, magnus::Error> {
    let context = &CTX.get().unwrap().context();

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

    // let curdir = std::env::current_dir().map_err(|err| BeaverRubyError::from(err))?;
    let script_dir = ruby.module_kernel().funcall("__dir__", ())?;

    let project: AnyProject = AnyProject::Beaver(project::beaver::Project::new(
        name.get()?,
        base_dir.get_opt().unwrap_or(script_dir),
        &context.get_build_dir().map_err(|err| BeaverRubyError::from(err))?
    ).map_err(|err| BeaverRubyError::from(err))?);

    let project_index = context.add_project(project).map_err(|err| BeaverRubyError::from(err))?;

    let project_accessor = ProjectAccessor { id: project_index };

    Ok(project_accessor)
}

// fn import_cmake(dir: String, cmake_flags: Option<magnus::RArray>) -> Result<(), magnus::Error> {
fn import_cmake(args: &[magnus::Value]) -> Result<(), magnus::Error> {
    let args = magnus::scan_args::scan_args::<
        (String,), // required
        (Option<magnus::RArray>,), // optional
        (),
        (),
        (),
        ()
    >(args)?;
    let dir = args.required.0;
    let cmake_flags = args.optional.0;
    let context = &CTX.get().unwrap().context();
    let cmake_flags = if let Some(cmake_flags) = cmake_flags {
        cmake_flags.into_iter().map(|v| v.to_string()).collect()
    } else {
        Vec::new()
    };
    let cmake_flags: Vec<&str> = cmake_flags.iter().map(|str| str.as_str()).collect();
    project::cmake::import(&PathBuf::from(dir), &cmake_flags, &context)
        .map_err(|err| BeaverRubyError::from(err).into())
}

// TODO: optional splat -> cargo flags
fn import_cargo(dir: String) -> Result<(), magnus::Error> {
    let context = &CTX.get().unwrap().context();
    project::cargo::import(&PathBuf::from(dir), vec![], &context)
        .map_err(|err| BeaverRubyError::from(err).into())
}

fn import_spm(dir: String) -> Result<ProjectAccessor, magnus::Error> {
    let context = &CTX.get().unwrap().context();
    let id = project::spm::import(&PathBuf::from(dir), &context)
        .map_err(BeaverRubyError::from)?;
    let project_accessor = ProjectAccessor { id };
    return Ok(project_accessor);
}

fn import_meson(args: &[magnus::Value]) -> Result<(), magnus::Error> {
    let args = magnus::scan_args::scan_args::<
        (String,), // required
        (Option<magnus::RArray>,), // optional
        (),
        (),
        (),
        ()
    >(args)?;
    let dir = args.required.0;
    let meson_flags = if let Some(flags) = args.optional.0 {
        flags.into_iter().map(|v| v.to_string()).collect()
    } else {
        Vec::new()
    };
    let meson_flags: Vec<_> = meson_flags.iter().map(|str| str.as_str()).collect();
    let context = &CTX.get().unwrap().context();
    project::meson::import(&PathBuf::from(dir), &meson_flags, &context)
        .map_err(|err| magnus::Error::from(BeaverRubyError::from(err)))?;
    Ok(())
}

pub fn register(ruby: &magnus::Ruby) -> crate::Result<()> {
    ruby.define_global_function("Project", magnus::function!(define_project, 1));
    ruby.define_global_function("import_cmake", magnus::function!(import_cmake, -1));
    ruby.define_global_function("import_cargo", magnus::function!(import_cargo, 1));
    ruby.define_global_function("import_spm", magnus::function!(import_spm, 1));
    ruby.define_global_function("import_meson", magnus::function!(import_meson, -1));

    Ok(())
}
