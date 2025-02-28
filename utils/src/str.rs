use std::ffi::{CString, NulError, OsStr};
use std::fmt::Display;

#[derive(Debug)]
pub enum OsStrConversionError {
    NulError(NulError),
    /// The string is not valid UTF-8.
    /// Only thrown on Windows
    EncodingError
}

impl std::error::Error for OsStrConversionError {}

impl Display for OsStrConversionError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            OsStrConversionError::NulError(err) => f.write_fmt(format_args!("NulError: {}", err)),
            OsStrConversionError::EncodingError => f.write_str("OSString is not valid UTF-8"),
        }
    }
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
