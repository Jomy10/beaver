use std::path::PathBuf;

use magnus::RString;
use magnus::value::ReprValue;

use crate::BeaverRubyError;

/// Check if any of the files changed since the last invocation of this command
fn files_changed(ruby: &magnus::Ruby, args: &[magnus::Value]) -> Result<bool, magnus::Error> {
    let caller_location: magnus::RArray = ruby.module_kernel().funcall("caller_locations", (0,))?;
    let flattened_locations: magnus::RString = caller_location.funcall("to_s", ())?;

    let files: Vec<PathBuf> = args.iter()
        .map(|arg| RString::from_value(*arg)
            .ok_or(BeaverRubyError::IncompatibleType(*arg, "String"))
            .and_then(|rstr| rstr.to_string().map_err(|err| BeaverRubyError::from(err)))
            .map(|str| PathBuf::from(str))
        ).collect::<Result<_, _>>()?;

    let ctx = &crate::CTX.get().unwrap();

    ctx.context().files_changed(flattened_locations.to_string()?, files)
        .map_err(|err| BeaverRubyError::from(err).into())
}

pub fn register(ruby: &magnus::Ruby) -> crate::Result<()> {
    ruby.define_global_function("files_changed", magnus::function!(files_changed, -1));

    Ok(())
}
