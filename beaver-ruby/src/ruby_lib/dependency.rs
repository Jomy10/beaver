use std::path::PathBuf;

use beaver::target::{Dependency, LibraryArtifactType, LibraryTargetDependency, PkgconfigFlagOption, PkgconfigOption};

use crate::{BeaverRubyError, CTX};

#[magnus::wrap(class = "Dependency")]
pub struct DependencyWrapper(pub(crate) Dependency);

impl DependencyWrapper {
    fn get_name(obj: magnus::Value) -> crate::Result<String> {
        if let Some(value) = magnus::RString::from_value(obj) {
            value.to_string().map_err(|err| err.into())
        } else if let Some(value) = magnus::Symbol::from_value(obj) {
            Ok(value.name()?.to_string())
        } else {
            Err(BeaverRubyError::IncompatibleType(obj, "String or Symbol"))
        }
    }

    fn new_static(obj: magnus::Value) -> Result<DependencyWrapper, magnus::Error> {
        // let context = unsafe { &*RBCONTEXT.assume_init_ref() };
        let context = &CTX.get().unwrap().context;

        let name = Self::get_name(obj)?;
        let target_ref = context.parse_target_ref(&name).map_err(|err| BeaverRubyError::from(err))?;
        let dependency = Dependency::Library(LibraryTargetDependency {
            target: target_ref,
            artifact: LibraryArtifactType::Staticlib
        });

        return Ok(DependencyWrapper(dependency));
    }

    fn new_dynamic(obj: magnus::Value) -> Result<DependencyWrapper, magnus::Error> {
        let context = &CTX.get().unwrap().context;

        let name = Self::get_name(obj)?;
        let target_ref = context.parse_target_ref(&name).map_err(|err| BeaverRubyError::from(err))?;
        let dependency = Dependency::Library(LibraryTargetDependency {
            target: target_ref,
            artifact: LibraryArtifactType::Dynlib
        });

        return Ok(DependencyWrapper(dependency));
    }

    fn parse_pkgconfig(name: &str, args: magnus::RArray) -> crate::Result<DependencyWrapper> {
        let mut iter = args.into_iter().peekable();
        let Some(first) = iter.peek() else {
            return Ok(DependencyWrapper(Dependency::pkgconfig(name, None, &[], &[])?));
        };

        let version_req: Option<String> = if let Some(str) = magnus::RString::from_value(*first) {
            _ = iter.next();
            Some(str.to_string()?)
        } else {
            None
        };

        #[allow(unused_mut)]
        let mut pkgconf_opts: Vec<PkgconfigOption> = Vec::new();
        let mut pkgconf_flag_opts: Vec<PkgconfigFlagOption> = Vec::new();

        for opt in iter {
            let Some(sym) = magnus::Symbol::from_value(opt) else {
                return Err(BeaverRubyError::IncompatibleType(opt, "Symbol"));
            };

            let str = sym.name()?;
            match str.as_ref() {
                "static" => { pkgconf_flag_opts.push(PkgconfigFlagOption::PreferStatic) },
                _ => { return Err(BeaverRubyError::ArgumentError(format!("Invalid pkgconfig option :{}", str))) },
            }
        }

        let pkgconf = Dependency::pkgconfig(name, version_req.as_ref().map(|str| str.as_str()), &pkgconf_opts, &pkgconf_flag_opts)?;

        Ok(DependencyWrapper(pkgconf))
    }

    fn new_pkgconfig(args: &[magnus::Value]) -> Result<DependencyWrapper, magnus::Error> {
        let args = magnus::scan_args::scan_args::<
            (magnus::Value,), // required
            (), // optional
            magnus::RArray, // splat
            (), // trailing
            (), // keyword
            () // block
        >(args)?;

        let name = Self::get_name(args.required.0)?;
        return Self::parse_pkgconfig(&name, args.splat).map_err(|err| err.into());
    }

    fn new_pkgconfig_direct(file: String) -> Result<DependencyWrapper, magnus::Error> {
        let file = PathBuf::from(file);
        let dependencies = Dependency::pkgconfig_from_file(&file).map_err(|err| BeaverRubyError::from(err))?;
        Ok(DependencyWrapper(dependencies))
    }

    fn new_system(name: magnus::Value) -> Result<DependencyWrapper, magnus::Error> {
        let name = Self::get_name(name)?;
        return Ok(DependencyWrapper(Dependency::system(&name)));
    }

    fn new_framework(name: magnus::Value) -> Result<DependencyWrapper, magnus::Error> {
        let name = Self::get_name(name)?;
        return Ok(DependencyWrapper(Dependency::framework(&name)));
    }

    fn new_flags(cflags: Option<Vec<String>>, linker_flags: Option<Vec<String>>) -> Result<DependencyWrapper, magnus::Error> {
        return Ok(DependencyWrapper(Dependency::Flags { cflags, linker_flags }));
    }
}

pub fn register(ruby: &magnus::Ruby) -> crate::Result<()> {
    let _class = ruby.define_class("Dependency", ruby.class_object())?;

    ruby.define_global_function("static", magnus::function!(DependencyWrapper::new_static, 1));
    ruby.define_global_function("dynamic", magnus::function!(DependencyWrapper::new_dynamic, 1));
    ruby.define_global_function("pkgconfig", magnus::function!(DependencyWrapper::new_pkgconfig, -1));
    ruby.define_global_function("pkgconfig_direct", magnus::function!(DependencyWrapper::new_pkgconfig_direct, 1));
    ruby.define_global_function("system_lib", magnus::function!(DependencyWrapper::new_system, 1));
    ruby.define_global_function("framework", magnus::function!(DependencyWrapper::new_framework, 1));
    ruby.define_global_function("flags", magnus::function!(DependencyWrapper::new_flags, 2));

    Ok(())
}
