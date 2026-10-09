use std::path::Path;

use crate::BeaverError;

pub fn path_to_str<'a>(path: &'a Path) -> crate::Result<&'a str> {
    let Some(str) = path.to_str() else {
        return Err(BeaverError::NonUTF8OsStr(path.as_os_str().to_os_string()));
    };
    return Ok(str);
}

/// Encode a path as string into a single path component, without % path separators
#[cfg(not(windows))]
pub fn encode_path(s: &str) -> String {
    let mut out = String::with_capacity(s.len() * 2);
    for b in s.bytes() {
        match b {
            b'A'..=b'Z' | b'a'..=b'z' | b'0'..=b'9' | b'-' | b'.' => out.push(b as char),
            _ => out.push_str(&format!("_{:02X}", b)),
        }
    }

    return out;
}

#[cfg(windows)]
pub fn encode_path(s: &str) -> String {
    use sha2::{Digest, Sha256};

    let digest = Sha256::digest(s.as_bytes());
    let hash = digest[..8].iter().map(|v| format!("{:02x}", v)).collect::<String>();
    let name = s.split("\\").last().unwrap_or("").chars().take(15).collect::<String>();
    format!("{hash}-{name}")
}
