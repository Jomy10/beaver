use std::path::PathBuf;

use beaver::target::parameters::{DefaultArgument, Files, Flags, Headers};
use beaver::target::{self, Dependency, ExecutableArtifactType, Language, LibraryArtifactType, LibraryTargetDependency, TArtifactType, Version};
use beaver::traits::{AnyExecutable, AnyLibrary, AnyTarget, Library, Project};
use beaver::{Beaver, BeaverError};
use magnus::value::ReprValue;
use magnus::Object;

use crate::{BeaverRubyError, RBCONTEXT};

use super::dependency::DependencyWrapper;
use super::target_accessor::TargetAccessor;
use super::Arg;

fn c_target_parse_ruby_args<ArtifactType: TArtifactType>(ruby: &magnus::Ruby, args: magnus::RHash, context: &Beaver) -> crate::Result<target::c::TargetDescriptor<ArtifactType>> {
    // let ruby = magnus::Ruby::get().map_err(|err| BeaverRubyError::from(err))?;

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

    args.foreach(|key: magnus::Symbol, value: magnus::Value| {
        match key.name()?.as_ref() {
            "name" => {
                let value = if let Some(str) = magnus::RString::from_value(value) {
                    str.to_string()?
                } else if let Some(sym) = magnus::Symbol::from_value(value) {
                    sym.name()?.to_string()
                } else {
                    return Err(BeaverRubyError::IncompatibleType(value, "String or Symbol").into());
                };
                name.set(value)?;
            },
            "description" => {
                let Some(value) = magnus::RString::from_value(value) else {
                    return Err(BeaverRubyError::IncompatibleType(value, "String").into());
                };
                desc.set(value.to_string()?)?;
            },
            "homepage" => {
                let Some(value) = magnus::RString::from_value(value) else {
                    return Err(BeaverRubyError::IncompatibleType(value, "String").into());
                };
                let strval = unsafe {value.as_str()?};
                homepage.set(url::Url::parse(strval).map_err(|err| BeaverRubyError::from(err))?)?;
            },
            "version" => {
                let value = if let Some(str) = magnus::RString::from_value(value) {
                    str.to_string()?
                } else if let Some(num) = magnus::Fixnum::from_value(value) {
                    num.to_i64().to_string()
                } else if let Some(f) = magnus::Float::from_value(value) {
                    f.to_f64().to_string()
                } else {
                    return Err(BeaverRubyError::IncompatibleType(value, "String, Fixnum or Float").into());
                };
                let strval = value.as_str();
                version.set(Version::parse(strval))?;
            },
            "license" => {
                let Some(value) = magnus::RString::from_value(value) else {
                    return Err(BeaverRubyError::IncompatibleType(value, "String").into());
                };
                license.set(value.to_string()?)?;
            },
            "language" => {
                let langval = if let Some(value) = magnus::RString::from_value(value) {
                    Language::parse(unsafe { value.as_str()? })
                } else if let Some(sym) = magnus::Symbol::from_value(value) {
                    Language::parse(&sym.name()?)
                } else {
                    return Err(BeaverRubyError::IncompatibleType(value, "String or Symbol").into());
                };
                let Some(langval) = langval else {
                    return Err(BeaverRubyError::ArgumentError(format!("Invalid language {}", value)).into());
                };
                language.set(langval)?;
            },
            "sources" => {
                let files = if let Some(str) = magnus::RString::from_value(value) {
                    Files::from_pat(unsafe { str.as_str()? })
                } else if let Some(arr) = magnus::RArray::from_value(value) {
                    let rstrarr: Vec<(Option<magnus::RString>, magnus::Value)> = arr.into_iter()
                            .map(|value| (magnus::RString::from_value(value), value))
                            .collect();
                    let pats = rstrarr.iter()
                        // .map(|value| (magnus::RString::from_value(value), value))
                        .map(|(string, value)| {
                            match string {
                                Some(str) => unsafe { str.as_str() },
                                None => Err(BeaverRubyError::IncompatibleType(*value, "String").into()),
                            }
                        }).collect::<Result<Vec<&str>, magnus::Error>>()?;
                    Files::from_pats(&pats)
                } else {
                    return Err(BeaverRubyError::IncompatibleType(value, "Array or String").into());
                }.map_err(|err| BeaverRubyError::from(err))?;
                // let files = Files::from_pats(&value).map_err(|err| BeaverRubyError::from(err))?;
                sources.set(files)?;
            },
            "cflags" => {
                let flags = if value.is_kind_of(ruby.class_string()) || value.is_kind_of(ruby.class_array()) {
                    Flags::new(parse_to_string_vec(value)?, Vec::new())
                } else if let Some(hash) = magnus::RHash::from_value(value) {
                    let public_flags = if let Some(value) = hash.get(magnus::Symbol::new("public")) {
                        parse_to_string_vec(value)?
                    } else {
                        Vec::new()
                    };
                    let private_flags = if let Some(value) = hash.get(magnus::Symbol::new("private")) {
                        parse_to_string_vec(value)?
                    } else {
                        Vec::new()
                    };
                    Flags::new(public_flags, private_flags)
                } else {
                    return Err(BeaverRubyError::IncompatibleType(value, "Array, Hash or String").into());
                };
                cflags.set(flags)?;
            },
            "headers" | "include" => {
                let value = if value.is_kind_of(ruby.class_string()) || value.is_kind_of(ruby.class_array()) {
                    Headers::new(parse_to_string_vec(value)?.into_iter().map(|str| PathBuf::from(str)).collect(), Vec::new())
                } else if let Some(hash) = magnus::RHash::from_value(value) {
                    let public_headers = if let Some(value) = hash.get(magnus::Symbol::new("public")) {
                        parse_to_string_vec(value)?.into_iter().map(|str| PathBuf::from(str)).collect()
                    } else {
                        Vec::new()
                    };
                    let private_headers = if let Some(value) = hash.get(magnus::Symbol::new("private")) {
                        parse_to_string_vec(value)?.into_iter().map(|str| PathBuf::from(str)).collect()
                    } else {
                        Vec::new()
                    };
                    Headers::new(public_headers, private_headers)
                } else {
                    return Err(BeaverRubyError::IncompatibleType(value, "Array, Hash or String").into());
                };
                headers.set(value)?;
            },
            "linker_flags" => {
                linker_flags.set(parse_to_string_vec(value)?)?;
            },
            "artifacts" => {
                let value = if let Some(str) = magnus::RString::from_value(value) {
                    vec![ArtifactType::parse(unsafe { str.as_str()? }).map_err(|err| BeaverRubyError::from(err))?]
                } else if let Some(sym) = magnus::Symbol::from_value(value) {
                    vec![ArtifactType::parse(&sym.name()?).map_err(|err| BeaverRubyError::from(err))?]
                } else if let Some(arr) = magnus::RArray::from_value(value) {
                    arr.into_iter().map(|value| {
                        if let Some(str) = magnus::RString::from_value(value) {
                            ArtifactType::parse(unsafe { str.as_str()? }).map_err(|err| BeaverRubyError::from(err).into())
                        } else if let Some(sym) = magnus::Symbol::from_value(value) {
                            ArtifactType::parse(&sym.name()?).map_err(|err| BeaverRubyError::from(err).into())
                        } else {
                            Err(BeaverRubyError::IncompatibleType(value, "Symbol or String").into())
                        }
                    }).collect::<Result<Vec<ArtifactType>, magnus::Error>>()?
                } else {
                    return Err(BeaverRubyError::IncompatibleType(value, "Array, symbol or string").into());
                };
                artifacts.set(DefaultArgument::Some(value))?
            },
            "dependencies" => {
                let value = if let Some(arr) = magnus::RArray::from_value(value) {
                    arr.into_iter().map(|value| {
                        parse_dependency(value, context)
                    }).collect::<crate::Result<Vec<Dependency>>>()
                } else {
                    parse_dependency(value, context).map(|dep| vec![dep])
                }?;
                dependencies.set(value)?;
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
    })
}

/// Parses a ruby string or array into a vector of strings
fn parse_to_string_vec(value: magnus::Value) -> crate::Result<Vec<String>> {
    if let Some(str) = magnus::RString::from_value(value) {
        Ok(vec![str.to_string()?])
    } else if let Some(arr) = magnus::RArray::from_value(value) {
        let pubflags = arr.into_iter().map(|value| {
            match magnus::RString::from_value(value) {
                Some(val) => val.to_string(),
                None => Err(BeaverRubyError::IncompatibleType(value, "String").into())
            }
        }).collect::<Result<Vec<String>, magnus::Error>>()?;
        Ok(pubflags)
    } else {
        Err(BeaverRubyError::IncompatibleType(value, "Array or String"))
    }
}

fn parse_dependency(value: magnus::Value, context: &Beaver) -> crate::Result<Dependency> {
    if let Some(str) = magnus::RString::from_value(value) {
        return parse_lib_dependency_from_str(unsafe { str.as_str()? }, None, context).map(|libdep| Dependency::Library(libdep));
    } else if let Some(symbol) = magnus::Symbol::from_value(value) {
        return parse_lib_dependency_from_str(symbol.name()?.as_ref(), None, context).map(|libdep| Dependency::Library(libdep));
    } else if let Some(dep) = magnus::RTypedData::from_value(value) {
        let w: &DependencyWrapper = dep.get()?;
        return Ok(w.0.clone());
    } else {
        return Err(BeaverRubyError::IncompatibleType(value, "String, Symbol or Dependency class"))
    }
}

/// When artifact is None, will select the default artifact
fn parse_lib_dependency_from_str(dep: &str, artifact: Option<LibraryArtifactType>, context: &Beaver) -> crate::Result<LibraryTargetDependency> {
    let target_ref = context.parse_target_ref(dep)?;
    let artifact: Result<LibraryArtifactType, BeaverRubyError> = match artifact {
        Some(artifact) => Ok(artifact),
        None => context.with_project_and_target(&target_ref, |_, target| {
            if let AnyTarget::Library(target) = target {
                match target.default_library_artifact() {
                    Some(artifact) => Ok(artifact),
                    None => Err(BeaverError::AnyError(format!("Dependency {} has not artifacts to link against", dep)))
                }
            } else {
                Err(BeaverError::AnyError(format!("Dependency {} should be a library, not an executable", dep)))
            }
        }).map_err(Into::into)
    };

    artifact.map(|artifact| {
        LibraryTargetDependency {
            target: target_ref,
            artifact,
        }
    })
}

fn def_c_library(ruby: &magnus::Ruby, args: magnus::RHash) -> Result<TargetAccessor, magnus::Error> {
    let context = unsafe { &*RBCONTEXT.assume_init() };

    let ctarget_desc: target::c::TargetDescriptor<LibraryArtifactType> = c_target_parse_ruby_args(ruby, args, &context)?;
    let library = AnyLibrary::C(target::c::Library::new_desc(ctarget_desc));

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

fn def_c_executable(ruby: &magnus::Ruby, args: magnus::RHash) -> Result<TargetAccessor, magnus::Error> {
    let context = unsafe { &*RBCONTEXT.assume_init() };

    let ctarget_desc: target::c::TargetDescriptor<ExecutableArtifactType> = c_target_parse_ruby_args(ruby, args, &context)?;
    let exe = AnyExecutable::C(target::c::Executable::new_desc(ctarget_desc));

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

pub fn register(ruby: &magnus::Ruby) -> crate::Result<()> {
    let c_mod = ruby.define_module("C")?;
    c_mod.define_singleton_method("Library", magnus::function!(def_c_library, 1))?;
    c_mod.define_singleton_method("Executable", magnus::function!(def_c_executable, 1))?;

    Ok(())
}
