use std::path::PathBuf;

use crate::{BeaverRubyError, RBCONTEXT};

fn build_dir(str: String) -> Result<Option<()>, magnus::Error> {
    let context = unsafe { &*RBCONTEXT.assume_init() };
    let path = PathBuf::from(str);

    context.set_build_dir(path).map_err(|err| BeaverRubyError::from(err))?;

    return Ok(None);
}

pub fn register(ruby: &magnus::Ruby) -> crate::Result<()> {
    ruby.define_global_function("build_dir", magnus::function!(build_dir, 1));

    return Ok(());
}
