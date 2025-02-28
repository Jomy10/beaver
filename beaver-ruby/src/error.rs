use std::io;

use beaver::BeaverError;
use rutie::{Exception, Object, RString};

#[derive(thiserror::Error, Debug)]
pub enum BeaverRubyError {
    #[error("{0}")]
    BeaverError(#[from] BeaverError),

    #[error("Couldn't open script file: {0}")]
    ScriptFileOpenError(io::Error),
    #[error("Couldn't read script file: {0}")]
    ScriptFileReadError(io::Error),

    // TODO: show code where exception occurred
    #[error("Exception occured: {}\n{}", .0.to_s(), .0.backtrace().unwrap().into_iter().map(|val| unsafe { val.send("to_s", &[]).to::<RString>().to_string() }).collect::<Vec<String>>().join("\n"))]
    RubyException(rutie::AnyException),

    #[error("{0:?}")]
    OsStrConversionError(#[from] OsStrConversionError),

    // General IO Error
    #[error("IO Error: {0}")]
    IOError(#[from] io::Error)
}

pub type Result<S> = std::result::Result<S, BeaverRubyError>;

macro_rules! raise {
    ($exc: expr) => {
        {
            rutie::VM::raise_ex($exc);
            unreachable!();
        }
    };
    ($klass: expr, $msg: expr) => {
        {
            rutie::VM::raise($klass, $msg);
            unreachable!();
        }
    };
}

pub(crate) use raise;
use utils::str::OsStrConversionError;
