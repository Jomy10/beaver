use std::io;
use std::path::Path;

/// Send a message to the client pipe
#[inline]
pub fn send_message(pipe: &Path, message: &[u8]) -> io::Result<()> {
    std::fs::write(pipe, message)
}
