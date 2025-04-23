use std::io::{self, Write};
use std::os::unix::net::{UnixListener, UnixStream};
use std::path::{Path, PathBuf};
use std::thread::JoinHandle;

use log::{error, trace};

use super::ReceiveResult;

#[derive(thiserror::Error)]
pub enum Error {
    #[error(transparent)]
    Boxed(#[from] Box<dyn std::error::Error + Send>),
    #[error(transparent)]
    Io(#[from] io::Error),
}

impl std::fmt::Debug for Error {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        // Automatically get propper error messages from main function returning a result
        std::fmt::Display::fmt(self, f)
    }
}

#[derive(Debug)]
pub struct Socket {
    pub thread_handle: JoinHandle<Result<(), Error>>,
    pub socket_file: PathBuf
}

impl Socket {
    pub fn sh_write_str_netcat(&self, netcat: &Path, data: &str, out: &mut String) -> std::fmt::Result {
        use std::fmt::Write;

        let netcat = netcat.to_str().unwrap();

        // let mut args: Vec<&str> = Vec::new();
        // #[cfg(any(target_os = "macos", target_os = "freebsd", target_os = "openbsd", target_os = "dragonfly", target_os = "netbsd"))] {
            // args.push("-U");
        // }
        let socket_file = self.socket_file.to_str().unwrap();
        // args.push(socket_file);
        let args = ["-U", socket_file];

        out.write_fmt(format_args!("echo \"{}\" | {} {}",
            data.replace("\"", "\\\""),
            netcat,
            args.iter().map(|str| format!("\"{str}\"")).collect::<Vec<String>>().join(" "),
        ))
    }

    pub fn send(&self, cmd: &str) -> io::Result<()> {
        let mut stream = UnixStream::connect(&self.socket_file)?;

        stream.write(cmd.as_bytes())?;

        Ok(())
    }
}

pub fn listen(
    name: &str,
    receive_cb: impl Fn(&mut UnixStream) -> Result<ReceiveResult, Box<dyn std::error::Error + Send>> + Send + 'static
) -> Result<Socket, io::Error> {
    let file = std::env::temp_dir().join(name.to_string() + ".socket");
    if file.exists() {
        std::fs::remove_file(&file)?;
    }

    let listener = UnixListener::bind(&file)?;

    trace!("Listening on unix socket {:?}", &file);

    let handle = std::thread::spawn(move || -> Result<(), Error> {
        for stream in listener.incoming() {
            let mut stream = stream?;
            match receive_cb(&mut stream) {
                Ok(ReceiveResult::Close) => break,
                Ok(_) => {},
                Err(err) => {
                    error!("{}", err);
                    return Err(Error::Boxed(err));
                },
            }
        }

        Ok(())
    });

    Ok(Socket {
        thread_handle: handle,
        socket_file: file
    })
}
