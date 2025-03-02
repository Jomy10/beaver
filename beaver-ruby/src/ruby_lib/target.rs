use std::path::PathBuf;

use beaver::target::parameters::{DefaultArgument, Files, Flags, Headers};
use beaver::target::{c, Dependency, ExecutableArtifactType, Language, LibraryArtifactType, LibraryTargetDependency, PkgconfigFlagOption, PkgconfigOption, TArtifactType, Version};
use beaver::traits::{AnyExecutable, AnyLibrary, AnyTarget, Library, Project};
use beaver::{Beaver, BeaverError};
use log::{trace, warn};
use rutie::{class, methods, AnyException, AnyObject, Class, Exception, Fixnum, Module, Object, RString, Symbol};

use crate::{get_context, raise};
use crate::rutie_ext::{RbValue, RutieArrayExt, RutieExceptionExt, RutieObjExt};

class!(TargetAccessor);

fn c_target_parse_cflags_string_or_array(val: RbValue) -> Result<Option<Vec<String>>, AnyException> {
    match val {
        RbValue::RString(str) => Ok(Some(vec![str.to_string()])),
        RbValue::Array(arr) => {
            let flags = arr.to_str_vec()?;
            Ok(Some(flags))
        },
        _ => Ok(None)
    }
}

fn c_target_parse_headers_string_or_array(val: RbValue) -> Result<Option<Vec<PathBuf>>, AnyException> {
    match val {
        RbValue::RString(str) => {
            let path = PathBuf::from(str.to_str());
            Ok(Some(vec![path]))
        },
        RbValue::Array(arr) => {
            let paths = arr.to_path_vec()?;
            Ok(Some(paths))
        },
        _ => Ok(None)
    }
}

/// Parse a single dependency element
fn c_target_parse_dependency(obj: AnyObject, context: &Beaver) -> Result<Dependency, AnyException> {
    match obj.vty() {
        RbValue::RString(str) => c_target_parse_library_dependency_from_str(str.to_str(), None, context).map(|d| Dependency::Library(d)),
        RbValue::Symbol(sym) => c_target_parse_library_dependency_from_str(sym.to_str(), None, context).map(|d| Dependency::Library(d)),
        RbValue::Object(obj) => {
            let str = obj.instance_variable_get("@string")
                .try_convert_to::<RString>()
                .expect("@string property of Dependency should be a string!");
            let str = str.to_str();
            let ty = obj.instance_variable_get("@type").try_convert_to::<Symbol>().expect("@type property of Dependency should be symbol!");
            let ty = ty.to_str();
            match ty {
                "static" => c_target_parse_library_dependency_from_str(str, Some(LibraryArtifactType::Staticlib), context).map(|d| Dependency::Library(d)),
                "dynamic" => c_target_parse_library_dependency_from_str(str, Some(LibraryArtifactType::Dynlib), context).map(|d| Dependency::Library(d)),
                "system" => Ok(Dependency::Flags { cflags: None, linker_flags: Some(vec![format!("-l{}", str.to_string())]) }),
                "pkgconfig" => {
                    let version_req = obj.instance_variable_get("@version_req");
                    let version_req: Option<String> = if version_req.is_nil() { None } else { Some(version_req.try_convert_to::<RString>().expect("should be a string").to_string()) };
                    let options: rutie::Array = obj.instance_variable_get("@options").try_convert_to().expect("should be an array");
                    let options = options.into_iter().fold((Vec::<PkgconfigOption>::new(), Vec::<PkgconfigFlagOption>::new()), |acc, obj| {
                        let mut acc = acc;
                        let sym = obj.try_convert_to::<Symbol>().expect("should be a symbol");
                        match sym.to_str() {
                            "static" => acc.1.push(PkgconfigFlagOption::PreferStatic),
                            "with_path" => todo!(),
                            _ => warn!("Unrecognised option {:?}", sym)
                        }
                        acc
                    });
                    Dependency::pkgconfig(
                        str,
                        version_req.as_deref(),
                        &options.0,
                        &options.1
                    ).map_err(|err| AnyException::new("RuntimeError", Some(&format!("{}", err))))
                },
                _ => Err(AnyException::new("RuntimeError", Some(&format!("invalid dependency type {}", ty))))
            }
        },
        _ => Err(AnyException::argerr(&format!("Invalid dependency object: {:?}", obj.vty())))
    }
}

fn c_target_parse_library_dependency_from_str(dep: &str, artifact: Option<LibraryArtifactType>, context: &Beaver) -> Result<LibraryTargetDependency, AnyException> {
    context.parse_target_ref(dep).map(|target_ref| {
        match artifact.map(|v| Ok(v)).unwrap_or(context.with_project_and_target(&target_ref, |_, target| {
            if let AnyTarget::Library(target) = target {
                match target.default_library_artifact() {
                    Some(artifact) => Ok(artifact),
                    None => Err(BeaverError::AnyError(format!("Dependency {} has no artifacts to link against", dep))),
                }
            } else {
                Err(BeaverError::AnyError(format!("Dependency {} should be a library, not an executable", dep)))
            }
        })) {
            Ok(artifact) => Ok(LibraryTargetDependency {
                target: target_ref,
                artifact,
            }),
            Err(err) => Err(err)
        }
    }).map_err(|err| AnyException::argerr(&err.to_string()))?
        .map_err(|err| AnyException::argerr(&err.to_string()))
}

fn c_target_parse_ruby_args<ArtifactType: TArtifactType>(args: rutie::Hash, context: &Beaver) -> c::TargetDescriptor<ArtifactType> {
    let mut name: Option<String> = None;
    let mut description: Option<String> = None;
    let mut homepage: Option<url::Url> = None;
    let mut version: Option<Version> = None;
    let mut license: Option<String> = None;
    let mut language: Language = Language::C;
    let mut sources: Option<Files> = None;
    let mut cflags: Option<Flags> = None;
    let mut headers: Option<Headers> = None;
    let mut linker_flags: Option<Vec<String>> = None;
    let mut artifacts: Option<DefaultArgument<Vec<ArtifactType>>> = None;
    let mut dependencies: Option<Vec<Dependency>> = None;

    args.each(|key, val| {
        let key = match key.try_convert_to::<Symbol>() {
            Ok(key) => key,
            Err(err) => raise!(err),
        };

        match key.to_str() {
            "name" => {
                 name = Some(match val.vty() {
                    RbValue::RString(str) => str.to_string(),
                    RbValue::Symbol(sym) => sym.to_string(),
                    _ => raise!(AnyException::argerr("Argument `name` should be a string or a symbol"))
                });
            },
            "description" => {
                description = Some(match val.vty() {
                    RbValue::RString(str) => str.to_string(),
                    _ => raise!(AnyException::argerr("Argument `description` should be a string"))
                });
            },
            "homepage" => {
                homepage = Some(match val.vty() {
                    RbValue::RString(str) => match url::Url::parse(str.to_str()) {
                        Ok(val) => val,
                        Err(parse_err) => raise!(AnyException::argerr(&format!("Failed to parse url of homepage `{}`: {}", str.to_str(), parse_err)))
                    },
                    _ => raise!(AnyException::argerr("Argument `homepage` should be a string"))
                })
            },
            "version" => {
                version = match val.vty() {
                    RbValue::Nil => None,
                    RbValue::RString(str) => Some(Version::parse(str.to_str())),
                    RbValue::Fixnum(num) => Some(Version::Any(num.to_i64().to_string())),
                    RbValue::Float(f) => Some(Version::Any(f.to_f64().to_string())),
                    _ => raise!(AnyException::argerr("Argument `version` should be a string, integer or float"))
                }
            },
            "license" => {
                license = match val.vty() {
                    RbValue::Nil => None,
                    RbValue::RString(str) => Some(str.to_string()),
                    _ => raise!(AnyException::argerr("Argument `license` should be a string"))
                }
            },
            "language" => {
                language = match val.vty() {
                    RbValue::Symbol(sym) => {
                        let str = sym.to_str();
                        match Language::parse(str) {
                            Some(lang) => lang,
                            None => raise!(AnyException::argerr(&format!("`:{}` is not a valid langauge", str)))
                        }
                    },
                    RbValue::RString(str) => {
                        let str = str.to_str();
                        match Language::parse(str) {
                            Some(lang) => lang,
                            None => raise!(AnyException::argerr(&format!("`{}` is not a valid langauge", str)))
                        }
                    },
                    _ => raise!(AnyException::argerr("Argument `language` should be a symbol or a string"))
                }
            },
            "sources" => {
                sources = Some(match val.vty() {
                    RbValue::RString(str) => match Files::from_pat(str.to_str()) {
                        Ok(files) => files,
                        Err(err) => raise!(AnyException::argerr(&format!("{}", err))),
                    },
                    RbValue::Array(arr) => {
                        let pats = match arr.to_str_vec() {
                            Ok(pats) => pats,
                            Err(err) => raise!(err),
                        };
                        match Files::from_pats_iter(pats.iter().map(|pat| pat.as_str())) {
                            Ok(files) => files,
                            Err(err) => raise!(AnyException::argerr(&format!("{}", err)))
                        }
                    }
                    _ => raise!(AnyException::argerr("Argument `sources` should be an array of strings or a string")),
                })
            },
            "cflags" => {
                let vty = val.vty();
                cflags = Some(match vty {
                    RbValue::RString(_) | RbValue::Array(_) => match c_target_parse_cflags_string_or_array(vty) {
                        Ok(var) => Flags::new(var.unwrap(), Vec::new()),
                        Err(err) => raise!(err),
                    }
                    RbValue::Hash(hash) => {
                        let public = hash.at(&Symbol::new("public"));
                        let private = hash.at(&Symbol::new("private"));
                        let len = hash.length();

                        if len > 2 {
                            raise!(AnyException::argerr(&format!("Invalid argument for `cflags`: too many keys specified in `{:?}`. The hash should only contain `public` and/or `private` keys.", hash)))
                        } else if (len == 1 && public.is_nil() && private.is_nil()) || (len == 2 && (public.is_nil() || private.is_nil())) {
                            raise!(AnyException::argerr(&format!("Invalid argument for `cflags`: invalid key specified in `{:?}`. The hash should only contain `public` and/or `private` keys.", hash)))
                        } else {
                            let public = if private.is_nil() {
                                Vec::new()
                            } else {
                                match c_target_parse_cflags_string_or_array(public.vty()) {
                                    Ok(Some(val)) => val,
                                    Ok(None) => raise!(AnyException::argerr(&format!("Invalid argument for `cflags`: `public` key has invalid type `{:?}` (expected string or array)", public))),
                                    Err(err) => raise!(err),
                                }
                            };
                            let private = if private.is_nil() {
                                Vec::new()
                            } else {
                                match c_target_parse_cflags_string_or_array(private.vty()) {
                                    Ok(Some(val)) => val,
                                    Ok(None) => raise!(AnyException::argerr(&format!("Invalid argument for `cflags`: `public` key has invalid type `{:?}` (expected string or array)", private))),
                                    Err(err) => raise!(err),
                                }
                            };
                            Flags::new(public, private)
                        }
                    },
                    _ => raise!(AnyException::argerr("Argument `cflags` should be an array, string or hash"))
                });
            },
            "headers" | "include" => {
                if headers.is_some() {
                    raise!(AnyException::argerr("both keys `headers` and `include` are specified"));
                }
                let vty = val.vty();
                headers = Some(match vty {
                    RbValue::RString(_) | RbValue::Array(_) => match c_target_parse_headers_string_or_array(vty) {
                        Ok(val) => Headers::new(val.unwrap(), Vec::new()),
                        Err(err) => raise!(err),
                    }
                    RbValue::Hash(hash) => {
                        let public = hash.at(&Symbol::new("public"));
                        let private = hash.at(&Symbol::new("private"));
                        let len = hash.length();

                        if len > 2 {
                            raise!(AnyException::argerr(&format!("Invalid argument for `headers`: too many keys specified in `{:?}`. The hash should only contain `public` and/or `private` keys.", hash)))
                        } else if (len == 1 && public.is_nil() && private.is_nil()) || (len == 2 && (public.is_nil() || private.is_nil())) {
                            raise!(AnyException::argerr(&format!("Invalid argument for `headers`: invalid key specified in `{:?}`. The hash should only contain `public` and/or `private` keys.", hash)))
                        } else {
                            let public = if public.is_nil() {
                                Vec::new()
                            } else {
                                match c_target_parse_headers_string_or_array(public.vty()) {
                                    Ok(Some(val)) => val,
                                    Ok(None) => raise!(AnyException::argerr(&format!("Invalid argument for `headers`: `public` key has invalid type `{:?}` (expected string or array)", public))),
                                    Err(err) => raise!(err)
                                }
                            };
                            let private = if private.is_nil() {
                                Vec::new()
                            } else {
                                match c_target_parse_headers_string_or_array(private.vty()) {
                                    Ok(Some(val)) => val,
                                    Ok(None) => raise!(AnyException::argerr(&format!("Invalid argument for `cflags`: `public` key has invalid type `{:?}` (expected string or array)", private))),
                                    Err(err) => raise!(err)
                                }
                            };

                            Headers::new(public, private)
                        }
                    },
                    _ => raise!(AnyException::argerr("Argument `heades` should be an array, string or hash"))
                })
            },
            "linker_flags" => {
                linker_flags = Some(match val.vty() {
                    RbValue::Nil => Vec::new(),
                    RbValue::RString(str) => vec![str.to_string()],
                    RbValue::Array(arr) => match arr.to_str_vec() {
                        Ok(val) => val,
                        Err(err) => raise!(err),
                    },
                    _ => raise!(AnyException::argerr("Argument `linker_flags` should be an array of strings or a string")),
                });
            },
            "artifacts" => {
                artifacts = Some(match val.vty() {
                    RbValue::RString(str) => match ArtifactType::parse(str.to_str()) {
                        Ok(at) => DefaultArgument::Some(vec![at]),
                        Err(err) => raise!(AnyException::argerr(&err.to_string())),
                    },
                    RbValue::Symbol(sym) => match ArtifactType::parse(sym.to_str()) {
                        Ok(at) => DefaultArgument::Some(vec![at]),
                        Err(err) => raise!(AnyException::argerr(&err.to_string())),
                    },
                    RbValue::Array(arr) => {
                        let artifacts = arr.into_iter().map(|obj| {
                            match obj.vty() {
                                RbValue::RString(str) => ArtifactType::parse(str.to_str())
                                    .map_err(|err| AnyException::argerr(&err.to_string())),
                                RbValue::Symbol(sym) => ArtifactType::parse(sym.to_str())
                                    .map_err(|err| AnyException::argerr(&err.to_string())),
                                _ => Err(AnyException::argerr("Artifacts in array passed to argument `artifact` should be strings or symbols"))
                            }
                        }).collect::<Result<Vec<ArtifactType>, AnyException>>();
                        let artifacts = match artifacts {
                            Ok(artifacts) => artifacts,
                            Err(err) => raise!(err),
                        };
                        DefaultArgument::Some(artifacts)
                    }
                    _ => raise!(AnyException::argerr("Argument `artifact` should be an array, string or symbol"))
                });
            },
            "dependencies" => {
                dependencies = Some(match val.vty() {
                    RbValue::Nil => Vec::new(),
                    RbValue::Symbol(_) | RbValue::RString(_) | RbValue::Class(_) => match c_target_parse_dependency(val, context) {
                        Ok(dep) => vec![dep],
                        Err(err) => raise!(err)
                    },
                    RbValue::Array(arr) => {
                        match arr.into_iter().map(|obj| {
                            c_target_parse_dependency(obj, context)
                        }).collect::<Result<Vec<Dependency>, AnyException>>() {
                            Ok(val) => val,
                            Err(err) => raise!(err)
                        }
                    },
                    _ => raise!(AnyException::argerr("Argument `dependencies` should be an array or a string"))
                });
            },
            arg => raise!(AnyException::argerr(&format!("Unexpected argument {:?}", arg)))
        };
    });

    let name = match name {
        Some(name) => name,
        None => raise!(AnyException::argerr("Target requires a name")),
    };

    let sources = match sources {
        Some(sources) => sources,
        None => raise!(AnyException::argerr("C Target requires a `sources` argument")),
    };

    c::TargetDescriptor {
        name,
        description,
        homepage,
        version,
        license,
        language,
        sources,
        cflags: cflags.unwrap_or(Flags::new(Vec::new(), Vec::new())),
        headers: headers.unwrap_or(Headers::new(Vec::new(), Vec::new())),
        linker_flags: linker_flags.unwrap_or(Vec::new()),
        artifacts: artifacts.unwrap_or(DefaultArgument::Default),
        dependencies: dependencies.unwrap_or(Vec::new()),
    }
}

methods!(
    crate::GlobalModule,
    rtself,

    fn def_c_library(args: rutie::Hash) -> TargetAccessor {
        let args = match args {
            Ok(args) => args,
            Err(err) => {
                trace!("{:?}", err);
                raise!(Class::from_existing("ArgumentError"), "`C::Library` needs at least a `name` and `sources` argument");
            },
        };

        let context = get_context();

        let ctarget_desc: c::TargetDescriptor<LibraryArtifactType> = c_target_parse_ruby_args(args, &context.context);

        let library = AnyLibrary::CLibrary(c::Library::new_desc(ctarget_desc));

        match context.context.with_current_project_mut(|project| {
            match project.as_mutable() {
                Some(project) => {
                    let target_id = project.add_target(AnyTarget::Library(library))?;
                    let mut target_accessor = Class::from_existing("TargetAccessor").allocate();
                    target_accessor.instance_variable_set("@id", Fixnum::new(target_id as i64));
                    Ok(unsafe { target_accessor.to() })
                },
                None => Err(BeaverError::ProjectNotMutable(project.name().to_string()))
            }
        }) {
            Ok(acc) => acc,
            Err(err) => raise!(Class::from_existing("RuntimeError"), &format!("{}", err))
        }
    }

    fn def_c_executable(args: rutie::Hash) -> TargetAccessor {
        let args = match args {
            Ok(args) => args,
            Err(err) => {
                trace!("{:?}", err);
                raise!(Class::from_existing("ArgumentError"), "`C::Executable` needs at least a `name` and `sources` argument");
            }
        };

        let context = get_context();

        let ctarget_desc: c::TargetDescriptor<ExecutableArtifactType> = c_target_parse_ruby_args(args, &context.context);

        let exe = AnyExecutable::CExecutable(c::Executable::new_desc(ctarget_desc));

        match context.context.with_current_project_mut(|project| {
            match project.as_mutable() {
                Some(project) => {
                    let target_id = project.add_target(AnyTarget::Executable(exe))?;
                    let mut target_accessor = Class::from_existing("TargetAccessor").allocate();
                    target_accessor.instance_variable_set("@id", Fixnum::new(target_id as i64));
                    Ok(unsafe { target_accessor.to() })
                },
                None => Err(BeaverError::ProjectNotMutable(project.name().to_string())),
            }
        }) {
            Ok(acc) => acc,
            Err(err) => raise!(Class::from_existing("RuntimeError"), &format!("{}", err))
        }
    }
);

pub fn load(c: &mut rutie::Class) -> crate::Result<()> {
    _ = c;
    let mut target_acc_klass = Class::new("TargetAccessor", None);
    _ = &mut target_acc_klass;

    let mut c_mod = Module::new("C");
    c_mod.define_singleton_method("Library", def_c_library);
    c_mod.define_singleton_method("Executable", def_c_executable);

    Ok(())
}
