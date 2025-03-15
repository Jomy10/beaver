use std::path::Path;

use crate::BeaverError;

pub fn path_to_str<'a>(path: &'a Path) -> crate::Result<&'a str> {
    let Some(str) = path.to_str() else {
        return Err(BeaverError::NonUTF8OsStr(path.as_os_str().to_os_string()));
    };
    return Ok(str);
}
