use std::path::PathBuf;

use rutie::{methods, Class, Object};

use crate::{get_context, error::raise};

methods!(
    rutie::Class,
    rtself,

    fn build_dir(str: rutie::RString) -> rutie::NilClass {
        let build_dir = match str {
            Ok(str) => str,
            Err(err) => raise!(err)
        };

        let context = get_context();
        let path = PathBuf::from(build_dir.to_str());

        match context.context.set_build_dir(path) {
            Ok(()) => {},
            Err(err) => raise!(Class::from_existing("RuntimeError"), &err.to_string())
        }

        return rutie::NilClass::new();
    }
);

pub fn load(module: &mut rutie::Class) -> crate::Result<()> {
    module.define_method("build_dir", build_dir);

    return Ok(());
}
