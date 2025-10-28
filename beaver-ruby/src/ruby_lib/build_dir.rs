use std::path::PathBuf;

use crate::{BeaverRubyError, CTX};

fn build_dir(str: String) -> Result<(), magnus::Error> {
    let context = &CTX.get().unwrap().context();

    let path = PathBuf::from(str);

    context.set_build_dir(path).map_err(|err| BeaverRubyError::from(err))?;

    return Ok(());
}

pub fn register(ruby: &magnus::Ruby) -> crate::Result<()> {
    ruby.define_global_function("build_dir", magnus::function!(build_dir, 1));

    return Ok(());
}
