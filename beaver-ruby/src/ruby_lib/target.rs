use std::collections::HashMap;
use std::path::PathBuf;

use beaver::target::custom::BuildCommand;
use beaver::target::parameters::{DefaultArgument, Files, Flags, Headers};
use beaver::target::{self, c, Dependency, ExecutableArtifactType, Language, LibraryArtifactType, TArtifactType, Version};
use beaver::traits::{AnyExecutable, AnyLibrary, AnyTarget, Project};
use beaver::{Beaver, BeaverError};
use magnus::Object;
use url::Url;

use crate::ext::{MagnusArtifactConvertExt, MagnusConvertContextExt, MagnusConvertExt, MagnusFilesConvertExt, MagnusStringConvertExt};
use crate::{BeaverRubyError, CTX};

use super::target_accessor::TargetAccessor;
use super::Arg;

fn c_target_parse_ruby_args<ArtifactType: TArtifactType>(args: magnus::RHash, context: &Beaver) -> crate::Result<target::c::TargetDescriptor<ArtifactType>> {
    context.with_current_project(|project| {
        let project_base_dir = project.base_dir();

        let mut name = Arg::<String>::new("name");
        let mut desc = Arg::<String>::new("description");
        let mut homepage = Arg::<url::Url>::new("homepage");
        let mut version = Arg::<Version>::new("version");
        let mut license = Arg::<String>::new("license");
        let mut language = Arg::<Language>::new("language");
        let mut sources = Arg::<Files>::new("sources");
        let mut cflags = Arg::<Flags>::new("cflags");
        let mut headers = Arg::<Headers>::new("headers");
        let mut linker_flags = Arg::<Vec<String>>::new("linker_flags");
        let mut artifacts = Arg::<DefaultArgument<Vec<ArtifactType>>>::new("artifacts");
        let mut dependencies = Arg::<Vec<Dependency>>::new("dependencies");
        let mut settings = Arg::<Vec<c::Setting>>::new("settings");

        args.foreach(|key: magnus::Symbol, value: magnus::Value| {
            match key.name()?.as_ref() {
                "name" => {
                    let value = String::from_string_or_sym(value)?;
                    name.set(value)?;
                },
                "description" => {
                    let Some(value) = magnus::RString::from_value(value) else {
                        return Err(BeaverRubyError::IncompatibleType(value, "String").into());
                    };
                    desc.set(value.to_string()?)?;
                },
                "homepage" => {
                    let url = Url::try_from_value(value)?;
                    homepage.set(url)?;
                },
                "version" => {
                    let ver = Version::try_from_value(value)?;
                    version.set(ver)?;
                },
                "license" => {
                    let Some(value) = magnus::RString::from_value(value) else {
                        return Err(BeaverRubyError::IncompatibleType(value, "String").into());
                    };
                    license.set(value.to_string()?)?;
                },
                "language" => {
                    let langval = Language::try_from_value(value)?;
                    language.set(langval)?;
                },
                "sources" | "src" => {
                    let files = Files::try_from_value(value, project_base_dir)?;
                    sources.set(files)?;
                },
                "cflags" => {
                    let flags = Flags::try_from_value(value)?;
                    cflags.set(flags)?;
                },
                "headers" | "include" => {
                    let value = Headers::try_from_value(value)?;
                    headers.set(value)?;
                },
                "linker_flags" | "lflags" => {
                    let flags = Vec::<String>::try_from_value(value)?;
                    linker_flags.set(flags)?;

                },
                "artifacts" => {
                    let value = Vec::<ArtifactType>::try_from_value(value)?;
                    artifacts.set(DefaultArgument::Some(value))?
                },
                "dependencies" => {
                    let value = Vec::<Dependency>::try_from_value(value, context)?;
                    dependencies.set(value)?;
                },
                "settings" => {
                    let value = Vec::<c::Setting>::try_from_value(value)?;
                    settings.set(value)?;
                },
                keyname => { return Err(BeaverRubyError::InvalidKey(keyname.to_string()).into()); }
            }

            Ok(magnus::r_hash::ForEach::Continue)
        })?;

        Ok(target::c::TargetDescriptor {
            name: name.get()?,
            description: desc.get_opt(),
            homepage: homepage.get_opt(),
            version: version.get_opt(),
            license: license.get_opt(),
            language: language.get_opt().unwrap_or(Language::C),
            sources: sources.get()?,
            cflags: cflags.get_opt().unwrap_or(Flags::new(Vec::new(), Vec::new())),
            headers: headers.get_opt().unwrap_or(Headers::new(Vec::new(), Vec::new())),
            linker_flags: linker_flags.get_opt().unwrap_or(Vec::new()),
            artifacts: artifacts.get_opt().unwrap_or(DefaultArgument::Default),
            dependencies: dependencies.get_opt().unwrap_or(Vec::new()),
            settings: settings.get_opt().unwrap_or(Vec::new())
        })
    })
}

fn def_c_library(args: magnus::RHash) -> Result<TargetAccessor, magnus::Error> {
    let context = &CTX.get().unwrap().context();

    let ctarget_desc: target::c::TargetDescriptor<LibraryArtifactType> = c_target_parse_ruby_args(args, &context)?;
    let library = AnyLibrary::C(target::c::Library::new_desc(ctarget_desc).map_err(BeaverRubyError::from)?);

    context.with_current_project_mut(|project| {
        match project.as_mutable() {
            Some(mutproject) => {
                let target_id = mutproject.add_target(AnyTarget::Library(library))?;
                let target_accessor = TargetAccessor {
                    projid: project.id().unwrap(),
                    id: target_id,
                };
                Ok(target_accessor)
            },
            None => Err(BeaverError::ProjectNotMutable(project.name().to_string())),
        }
    }).map_err(|err| BeaverRubyError::from(err).into())
}

fn def_c_executable(args: magnus::RHash) -> Result<TargetAccessor, magnus::Error> {
    let context = &CTX.get().unwrap().context();

    let ctarget_desc: target::c::TargetDescriptor<ExecutableArtifactType> = c_target_parse_ruby_args(args, &context)?;
    let exe = AnyExecutable::C(target::c::Executable::new_desc(ctarget_desc).map_err(BeaverRubyError::from)?);

    context.with_current_project_mut(|project| {
        match project.as_mutable() {
            Some(mutproject) => {
                let target_id = mutproject.add_target(AnyTarget::Executable(exe))?;
                let target_accessor = TargetAccessor {
                    projid: project.id().unwrap(),
                    id: target_id
                };
                Ok(target_accessor)
            },
            None => Err(BeaverError::ProjectNotMutable(project.name().to_string())),
        }
    }).map_err(|err| BeaverRubyError::from(err).into())
}

fn def_custom_library(args: magnus::RHash) -> Result<TargetAccessor, magnus::Error> {
    // let context: &Arc<Beaver> = unsafe { &*RBCONTEXT.assume_init_ref() };
    let context = &CTX.get().unwrap().context();

    context.with_current_project_mut(|project| {
        let project_base_dir = project.base_dir();

        let mut name = Arg::<String>::new("name");
        let mut desc = Arg::<String>::new("description");
        let mut homepage = Arg::<url::Url>::new("homepage");
        let mut version = Arg::<Version>::new("version");
        let mut license = Arg::<String>::new("license");
        let mut language = Arg::<Language>::new("language");
        let mut sources = Arg::<Files>::new("sources");
        let mut cflags = Arg::<Vec<String>>::new("cflags");
        let mut headers = Arg::<Headers>::new("headers");
        let mut linker_flags = Arg::<Vec<String>>::new("linker_flags");
        let mut artifacts = Arg::<HashMap<LibraryArtifactType, PathBuf>>::new("artifacts");
        let mut dependencies = Arg::<Vec<Dependency>>::new("dependencies");
        let mut build_cmd = Arg::<BuildCommand>::new("build");

        args.foreach(|key: magnus::Symbol, value: magnus::Value| {
            match key.name()?.as_ref() {
                "name" => {
                    let value = String::from_string_or_sym(value)?;
                    name.set(value)?;
                },
                "description" => {
                    let Some(value) = magnus::RString::from_value(value) else {
                        return Err(BeaverRubyError::IncompatibleType(value, "String").into());
                    };
                    desc.set(value.to_string()?)?;
                },
                "homepage" => {
                    let url = Url::try_from_value(value)?;
                    homepage.set(url)?;
                },
                "version" => {
                    let ver = Version::try_from_value(value)?;
                    version.set(ver)?;
                },
                "license" => {
                    let Some(value) = magnus::RString::from_value(value) else {
                        return Err(BeaverRubyError::IncompatibleType(value, "String").into());
                    };
                    license.set(value.to_string()?)?;
                },
                "language" => {
                    let langval = Language::try_from_value(value)?;
                    language.set(langval)?;
                },
                "sources" => {
                    let files = Files::try_from_value(value, project_base_dir)?;
                    sources.set(files)?;
                },
                "cflags" => {
                    let flags = Vec::<String>::try_from_value(value)?;
                    cflags.set(flags)?;
                },
                "headers" | "include" => {
                    let value = Headers::try_from_value(value)?;
                    headers.set(value)?;
                },
                "linker_flags" | "ldflags" | "lflags" => {
                    let flags = Vec::<String>::try_from_value(value)?;
                    linker_flags.set(flags)?;

                },
                "artifacts" => {
                    let value = HashMap::<LibraryArtifactType, PathBuf>::try_from_value(value)?;
                    artifacts.set(value)?
                },
                "dependencies" => {
                    let value = Vec::<Dependency>::try_from_value(value, context)?;
                    dependencies.set(value)?;
                },
                "build" => {
                    let cmd = BuildCommand::try_from_value(value)?;
                    build_cmd.set(cmd)?
                },
                keyname => { return Err(BeaverRubyError::InvalidKey(keyname.to_string()).into()); }
            }

            Ok(magnus::r_hash::ForEach::Continue)
        })?;

        let library = AnyLibrary::Custom(target::custom::Library::new(
            name.get()?,
            version.get_opt(),
            desc.get_opt(),
            homepage.get_opt(),
            license.get_opt(),
            language.get()?,
            dependencies.get_opt().unwrap_or(Vec::new()),
            artifacts.get()?,
            linker_flags.get_opt().unwrap_or(Vec::new()),
            cflags.get_opt().unwrap_or(Vec::new()),
            build_cmd.get()?
        ));

        // context.with_current_project_mut(|project| {
        match project.as_mutable() {
            Some(mutproject) => {
                let target_id = mutproject.add_target(AnyTarget::Library(library))?;
                let target_accessor = TargetAccessor {
                    projid: project.id().unwrap(),
                    id: target_id
                };
                Ok(target_accessor)
            },
            None => Err(BeaverRubyError::from(BeaverError::ProjectNotMutable(project.name().to_string()))),
        }
    }).map_err(|err| err.into())
}

pub fn register(ruby: &magnus::Ruby) -> crate::Result<()> {
    let c_mod = ruby.define_module("C")?;
    c_mod.define_singleton_method("Library", magnus::function!(def_c_library, 1))?;
    c_mod.define_singleton_method("Executable", magnus::function!(def_c_executable, 1))?;

    let custom_mod = ruby.define_module("Custom")?;
    custom_mod.define_singleton_method("Library", magnus::function!(def_custom_library, 1))?;

    Ok(())
}
