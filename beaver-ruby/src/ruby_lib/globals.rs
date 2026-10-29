use std::path::PathBuf;

use crate::{BeaverRubyError, CTX};

fn build_dir(str: String) -> Result<(), magnus::Error> {
    let context = &CTX.get().unwrap().context();

    let path = PathBuf::from(str);

    context.set_build_dir(path).map_err(|err| BeaverRubyError::from(err))?;

    return Ok(());
}

fn add_global_cflags(flags: Vec<String>) -> Result<(), magnus::Error> {
    let context = &CTX.get().unwrap().context();
    context.add_global_cflags(flags.into_iter())
        .map_err(|err| BeaverRubyError::from(err).into())
}

fn add_global_linker_flags(flags: Vec<String>) -> Result<(), magnus::Error> {
    let context = &CTX.get().unwrap().context();
    context.add_global_linker_flags(flags.into_iter())
        .map_err(|err| BeaverRubyError::from(err).into())
}

pub fn register(ruby: &magnus::Ruby) -> crate::Result<()> {
    ruby.define_global_function("build_dir", magnus::function!(build_dir, 1))?;
    ruby.define_global_function("add_global_cflags", magnus::function!(add_global_cflags, 1))?;
    ruby.define_global_function("add_global_linker_flags", magnus::function!(add_global_linker_flags, 1))?;

    return Ok(());
}
