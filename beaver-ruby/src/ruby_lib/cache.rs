use std::path::PathBuf;

use magnus::{IntoValue, RString};
use magnus::value::ReprValue;
use log::*;

use crate::BeaverRubyError;

/// Check if any of the files changed since the last invocation of this command
fn files_changed(ruby: &magnus::Ruby, args: &[magnus::Value]) -> Result<bool, magnus::Error> {
    trace!("Checking files changed {:?}", args);
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

fn store(var_name: magnus::RString, val: magnus::value::Value) -> Result<(), magnus::Error> {
    let context = &crate::CTX.get().unwrap().context();
    let var_name = unsafe { var_name.as_str()? };
    let val: magnus::RString = val.funcall("to_s", ())?;
    let val = unsafe { val.as_str()? };
    context.store(var_name, val)
        .map_err(|err| BeaverRubyError::from(err).into())
}

fn get(ruby: &magnus::Ruby, var_name: magnus::RString) -> Result<magnus::value::Value, magnus::Error> {
    let context = &crate::CTX.get().unwrap().context();
    let var_name = unsafe { var_name.as_str()? };
    context.get(var_name)
        .map_err(|err| BeaverRubyError::from(err).into())
        .map(|val| match val {
            Some(str) => magnus::RString::new(&str).into_value(),
            None => ruby.qnil().into_value()
        })
}

pub fn register(ruby: &magnus::Ruby) -> crate::Result<()> {
    ruby.define_global_function("files_changed", magnus::function!(files_changed, -1));
    ruby.define_global_function("store", magnus::function!(store, 2));
    ruby.define_global_function("get", magnus::function!(get, 1));

    Ok(())
}
