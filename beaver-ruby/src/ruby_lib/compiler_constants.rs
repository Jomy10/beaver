use beaver::{BeaverError, tools};
use magnus::Object;

use crate::{BeaverRubyError, CTX};
use crate::ext::MagnusStringConvertExt;

fn get_tool(ruby: &magnus::Ruby, name: magnus::Value) -> Result<Option<magnus::RString>, magnus::Error> {
    let name = String::from_string_or_sym(name)?;

    let tool = match name.to_uppercase().as_str() {
        "CC" => Some(tools::cc.as_path()),
        "CXX" => Some(tools::cxx.as_path()),
        "LINKER" => Some(tools::link.as_path()),
        "LINKERXX" => Some(tools::link.as_path()),
        "GNUSTEP_CONFIG" => Some(tools::link.as_path()),
        "PKGCONFIG" => Some(tools::link.as_path()),
        "SH" => Some(tools::sh.as_path()),
        "CMAKE" => Some(tools::cmake.as_path()),
        "CARGO" => Some(tools::cargo.as_path()),
        "SWIFT" => Some(tools::swift.as_path()),
        "MESON" => Some(tools::meson.as_path()),
        _ => None,
    };

    if let Some(tool) = tool {
        Ok(Some(ruby.str_from_slice(tool.to_str()
            .ok_or_else(|| Into::<magnus::Error>::into(BeaverRubyError::BeaverError(BeaverError::NonUTF8OsStr(tool.as_os_str().into()))))?
            .as_bytes()
        )))
    } else {
        Ok(None)
    }
}

pub fn register(ruby: &magnus::Ruby) -> crate::Result<()> {
    let context = &CTX.get().unwrap().context();

    ruby.define_global_const("OPT", context.opt_mode().to_string())?; // TODO: to symbol

    let tools = ruby.define_module("TOOLS")?;
    tools.define_singleton_method("[]", magnus::function!(get_tool, 1))?;

    Ok(())
}
