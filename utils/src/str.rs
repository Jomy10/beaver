use std::ffi::{CString, NulError, OsStr};

pub enum OsStrConversionError {
    NulError(NulError),
    /// The string is not valid UTF-8.
    /// Only thrown on Windows
    EncodingError
}

// see: https://stackoverflow.com/questions/54374381/how-can-i-convert-a-windows-osstring-to-a-cstring
pub fn osstr_to_cstr(osstr: &OsStr) -> Result<CString, OsStrConversionError> {
    #[cfg(unix)]
    {
        use std::os::unix::ffi::OsStrExt;

        CString::new(osstr.as_bytes()).map_err(|err| OsStrConversionError::NulError(err))
    }

    #[cfg(not(unix))]
    {
        // Implementation for windows, but should work on any OS
        use std::str::FromStr;

        let str = match osstr.to_str() {
            Some(str) => Ok(str),
            None => Err(OsStrConversionError::EncodingError)
        }?;
        CString::from_str(str).map_err(|err| OsStrConversionError::NulError(err))
    }
}
