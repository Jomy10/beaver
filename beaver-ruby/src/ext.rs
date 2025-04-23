use std::collections::HashMap;
use std::hash::Hash;
use std::path::PathBuf;
use std::str::FromStr;

use beaver::target::custom::BuildCommand;
use beaver::target::parameters::{Files, Flags, Headers};
use beaver::target::{Dependency, Language, LibraryArtifactType, LibraryTargetDependency, TArtifactType, Version};
use beaver::traits::{AnyTarget, Library};
use beaver::{Beaver, BeaverError};
use magnus::value::ReprValue;
use utils::UnsafeSendable;

use crate::ruby_lib::dependency::DependencyWrapper;
use crate::BeaverRubyError;

/// Parses a ruby string or array into a vector of strings
pub(crate) fn parse_to_string_vec(value: magnus::Value) -> crate::Result<Vec<String>> {
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

pub trait MagnusArtifactConvertExt {
    fn try_from_value(value: magnus::Value) -> Result<Self, magnus::Error> where Self: Sized;
}

impl<ArtifactType: TArtifactType> MagnusArtifactConvertExt for Vec<ArtifactType> {
    fn try_from_value(value: magnus::Value) -> Result<Self, magnus::Error> where Self: Sized {
        if let Some(str) = magnus::RString::from_value(value) {
            Ok(vec![ArtifactType::parse(unsafe { str.as_str()? }).map_err(|err| BeaverRubyError::from(err))?])
        } else if let Some(sym) = magnus::Symbol::from_value(value) {
            Ok(vec![ArtifactType::parse(&sym.name()?).map_err(|err| BeaverRubyError::from(err))?])
        } else if let Some(arr) = magnus::RArray::from_value(value) {
            arr.into_iter().map(|value| {
                if let Some(str) = magnus::RString::from_value(value) {
                    ArtifactType::parse(unsafe { str.as_str()? }).map_err(|err| BeaverRubyError::from(err).into())
                } else if let Some(sym) = magnus::Symbol::from_value(value) {
                    ArtifactType::parse(&sym.name()?).map_err(|err| BeaverRubyError::from(err).into())
                } else {
                    Err(BeaverRubyError::IncompatibleType(value, "Symbol or String").into())
                }
            }).collect::<Result<Vec<ArtifactType>, magnus::Error>>()
        } else {
            Err(BeaverRubyError::IncompatibleType(value, "Array, symbol or string").into())
        }
    }
}

pub trait MagnusConvertExt {
    fn try_from_value(value: magnus::Value) -> Result<Self, magnus::Error> where Self: Sized;
}

impl MagnusConvertExt for url::Url {
    fn try_from_value(value: magnus::Value) -> Result<Self, magnus::Error> where Self: Sized {
        let Some(value) = magnus::RString::from_value(value) else {
            return Err(BeaverRubyError::IncompatibleType(value, "String").into());
        };
        let strval = unsafe { value.as_str()? };
        return url::Url::parse(strval).map_err(BeaverRubyError::from).map_err(Into::into);
    }
}

impl MagnusConvertExt for Version {
    fn try_from_value(value: magnus::Value) -> Result<Self, magnus::Error> where Self: Sized {
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
        return Ok(Version::parse(strval));
    }
}

impl MagnusConvertExt for Language {
    fn try_from_value(value: magnus::Value) -> Result<Self, magnus::Error> where Self: Sized {
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
        return Ok(langval);
    }
}

impl MagnusConvertExt for Files {
    fn try_from_value(value: magnus::Value) -> Result<Self, magnus::Error> where Self: Sized {
       if let Some(str) = magnus::RString::from_value(value) {
            return Files::from_pat(unsafe { str.as_str()? })
                .map_err(|err| BeaverRubyError::from(err)).map_err(Into::<magnus::Error>::into);
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
            return Files::from_pats(&pats)
                .map_err(|err| BeaverRubyError::from(err)).map_err(Into::<magnus::Error>::into);
        } else {
            return Err(BeaverRubyError::IncompatibleType(value, "Array or String").into());
        }
    }
}

impl MagnusConvertExt for Flags {
    fn try_from_value(value: magnus::Value) -> Result<Self, magnus::Error> where Self: Sized {
        let ruby = magnus::Ruby::get().unwrap();

        if value.is_kind_of(ruby.class_string()) || value.is_kind_of(ruby.class_array()) {
            Ok(Flags::new(parse_to_string_vec(value)?, Vec::new()))
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
            Ok(Flags::new(public_flags, private_flags))
        } else {
            Err(BeaverRubyError::IncompatibleType(value, "Array, Hash or String").into())
        }
    }
}

impl MagnusConvertExt for Headers {
    fn try_from_value(value: magnus::Value) -> Result<Self, magnus::Error> where Self: Sized {
        let ruby = magnus::Ruby::get().unwrap();

        if value.is_kind_of(ruby.class_string()) || value.is_kind_of(ruby.class_array()) {
            Ok(Headers::new(parse_to_string_vec(value)?.into_iter().map(|str| PathBuf::from(str)).collect(), Vec::new()))
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
            Ok(Headers::new(public_headers, private_headers))
        } else {
            Err(BeaverRubyError::IncompatibleType(value, "Array, Hash or String").into())
        }
    }
}

impl MagnusConvertExt for Vec<String> {
    fn try_from_value(value: magnus::Value) -> Result<Self, magnus::Error> where Self: Sized {
        parse_to_string_vec(value).map_err(Into::into)
    }
}

impl<ArtifactType: TArtifactType + Eq + Hash> MagnusConvertExt for HashMap<ArtifactType, PathBuf> {
    fn try_from_value(value: magnus::Value) -> Result<Self, magnus::Error> where Self: Sized {
        let Some(value) = magnus::RHash::from_value(value) else {
            return Err(BeaverRubyError::IncompatibleType(value, "Hash").into());
        };

        let mut map: HashMap<ArtifactType, PathBuf> = HashMap::new();

        value.foreach(|k: magnus::Value, v: magnus::Value| {
            let artifact = ArtifactType::parse(unsafe { k.to_s()? }.as_ref()).map_err(BeaverRubyError::from).map_err(Into::<magnus::Error>::into)?;
            let path = PathBuf::from_str(unsafe { v.to_s()? }.as_ref()).unwrap();

            map.insert(artifact, path);

            Ok(magnus::r_hash::ForEach::Continue)
        })?;

        return Ok(map);
    }
}

impl MagnusConvertExt for BuildCommand {
    fn try_from_value(value: magnus::Value) -> Result<Self, magnus::Error> where Self: Sized {
        let Some(proc) = magnus::block::Proc::from_value(value) else {
            return Err(BeaverRubyError::IncompatibleType(value, "Proc").into());
        };

        let proc = UnsafeSendable::new(proc);
        return Ok(BuildCommand(Box::new(move || {
            // TODO: run on ruby thread
            unsafe { proc.value().call([] as [magnus::Value; 0]) }
                .map(|_: magnus::Value| ())
                .map_err(|err| BeaverError::AnyError(err.to_string()))
        })));
    }
}

pub trait MagnusConvertContextExt {
    fn try_from_value(value: magnus::Value, context: &Beaver) -> Result<Self, magnus::Error> where Self: Sized;
}

impl MagnusConvertContextExt for Vec<Dependency> {
    fn try_from_value(value: magnus::Value, context: &Beaver) -> Result<Self, magnus::Error> where Self: Sized {
        if let Some(arr) = magnus::RArray::from_value(value) {
            arr.into_iter().map(|value| {
                parse_dependency(value, context)
            }).collect::<crate::Result<Vec<Dependency>>>()
                .map_err(BeaverRubyError::from)
                .map_err(Into::into)
        } else {
            parse_dependency(value, context).map(|dep| vec![dep])
                .map_err(Into::into)
        }
    }
}

pub trait MagnusStringConvertExt {
    fn from_string_or_sym(value: magnus::Value) -> Result<Self, magnus::Error> where Self: Sized;
}

impl MagnusStringConvertExt for String {
    fn from_string_or_sym(value: magnus::Value) -> Result<Self, magnus::Error> where Self: Sized {
        if let Some(str) = magnus::RString::from_value(value) {
            str.to_string()
        } else if let Some(sym) = magnus::Symbol::from_value(value) {
            Ok(sym.name()?.to_string())
        } else {
            Err(BeaverRubyError::IncompatibleType(value, "String or Symbol").into())
        }
    }
}
