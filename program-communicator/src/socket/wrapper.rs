use std::error::Error;
use std::io;

use super::ReceiveResult;

#[cfg(unix)]
mod unix {
    use std::error::Error;
    use std::io;
    use std::path::Path;

    pub trait SocketUnixExt {
        fn sh_write_str_netcat_and_wait(&self, mkfifo: &Path, cat: &Path, netcat: &Path, netcat_send_data: &str, response_file: impl AsRef<Path>, escape_dollar: bool, out: &mut String) -> std::fmt::Result;
        fn sh_write_str_netcat(&self, netcat: &Path, data: &str, out: &mut String) -> std::fmt::Result;
        fn wait(self) -> Result<(), Box<dyn Error + Send>>;
    }

    #[cfg(unix)]
    #[derive(Debug)]
    pub struct Socket(pub(crate) super::super::unix::Socket);

    impl Socket {
        pub fn send(&self, cmd: &str) -> io::Result<()> {
            self.0.send(cmd)
        }
    }

    #[cfg(unix)]
    impl SocketUnixExt for Socket {
        fn sh_write_str_netcat_and_wait(&self, mkfifo: &Path, cat: &Path, netcat: &Path, netcat_send_data: &str, response_file: impl AsRef<Path>, escape_dollar: bool, out: &mut String) -> std::fmt::Result {
            self.0.sh_write_str_netcat_and_wait(mkfifo, cat, netcat, netcat_send_data, response_file.as_ref(), escape_dollar, out)
        }

        fn sh_write_str_netcat(&self, netcat: &Path, data: &str, out: &mut String) -> std::fmt::Result {
            self.0.sh_write_str_netcat(netcat, data, out)
        }

        fn wait(self) -> Result<(), Box<dyn Error + Send>> {
            self.0.thread_handle.join().unwrap()
                .map_err(|err| Box::new(err) as Box<dyn Error + Send>)
        }
    }
}
#[cfg(unix)]
pub use unix::*;

pub fn listen(
    name: &str,
    receive_cb: impl Fn(&mut dyn io::Read) -> Result<ReceiveResult, Box<dyn Error + Send>> + Send + 'static
) -> Result<Socket, Box<dyn Error>> {
    #[cfg(unix)] {
        super::unix::listen(name, move |stream| {
            receive_cb(stream)
        })  .map(|socket| Socket(socket))
            .map_err(Into::into)
    }
}
