use std::num::{ParseFloatError, ParseIntError};
use std::process::ExitStatus;
use std::str::ParseBoolError;
use std::sync::{Arc, Mutex};

use magnus::error::RubyUnavailableError;
use magnus::value::ReprValue;
use utils::UnsafeSendable;

use crate::CTX;

#[derive(Debug, thiserror::Error)]
pub enum BeaverRubyError {
    #[error(transparent)]
    RubyUnavailableError(#[from] RubyUnavailableError),
    #[error("{1}")]
    MagnusError(magnus::Error, String),
    // #[error("{}",
    //     {
    //         if (unsafe { CTX_RC.assume_init().upgrade().unwrap() }.thread_id == std::thread::current().id()) {
    //             format!(
    //                 "{}{}",
    //                 .1,
    //                 // include a backtrace
    //                 .1.value().map_or("".to_string(), |value| value.funcall("backtrace", ())
    //                     .map_or("".to_string(), |value: magnus::Value| {
    //                         value.funcall("join", ("\n",))
    //                             .map_or("".to_string(), |value: magnus::RString| {
    //                                 match unsafe { value.as_str() } {
    //                                     Ok(val) => "\n".to_string() + val,
    //                                     Err(_) => "".to_string()
    //                                 }
    //                             })
    //                         })
    //                 )
    //             )
    //         } else {
    //             let _out: Arc<Mutex<String>> = Arc::new(Mutex::new(String::new()));
    //             let out = _out.clone();
    //             block_execute_on(.0, Box::new(|| {
    //                 let out = out.lock().unwrap();
    //                 *out = format!(
    //                     "{}{}",
    //                     .1,
    //                     // include a backtrace
    //                     .1.value().map_or("".to_string(), |value| value.funcall("backtrace", ())
    //                         .map_or("".to_string(), |value: magnus::Value| {
    //                             value.funcall("join", ("\n",))
    //                                 .map_or("".to_string(), |value: magnus::RString| {
    //                                     match unsafe { value.as_str() } {
    //                                         Ok(val) => "\n".to_string() + val,
    //                                         Err(_) => "".to_string()
    //                                     }
    //                                 })
    //                             })
    //                     )
    //                 );
    //                 Ok(())
    //             })).unwrap();

    //             _out.lock().unwrap().clone()
    //         }
    //     }
    // )]
    // MagnusError(RubyThreadSender<'static>, magnus::Error, Arc<BeaverRubyContext>), // The BeaverRubyContext should be kept alive so we can construct the backtrace
    #[error("IO Error: {0}")]
    IOError(#[from] std::io::Error),
    #[error(transparent)]
    BeaverError(#[from] beaver::BeaverError),
    #[error("Cannot convert {} to {}", {
        let ctx = &CTX.get().unwrap();
        if ctx.thread_id == std::thread::current().id() {
            .0.to_string()
        } else {
            // scuffed implementation
            let res = Arc::new(Mutex::new(String::new()));
            let value = UnsafeSendable::new(&raw const *.0);
            let _res = res.clone();
            ctx.block_execute_on(Box::new(move || {
                let value = unsafe { *value.value() };
                *_res.lock().unwrap() = unsafe { (*value).to_string() };
                Ok(())
            })).unwrap();
            res.lock().unwrap().clone()
        }
    }, .1)]
    IncompatibleType(magnus::Value, &'static str),
    #[error("{0}")]
    ArgumentError(String),
    #[error("Found invalid key {0}")]
    InvalidKey(String),
    #[error("Couldn't parse URL: {0}")]
    URLParseError(#[from] url::ParseError),

    #[error("Couldn't convert value to float: {0}")]
    FloatConversionError(#[from] ParseFloatError),
    #[error("Couldn't convert value to int: {0}")]
    IntegerConversionError(#[from] ParseIntError),
    #[error("Couldn't convert value to bool: {0}")]
    BooleanConversionError(#[from] ParseBoolError),
    #[error("{0}")]
    CLIArgumentError(String),
    #[error("Exit status {0} while executing {1}")]
    ShExitFailure(ExitStatus, String),
    #[error("Invalid arguments (couldn't split): {0}")]
    ErroneousSplitArgsInput(String),
    #[error("Couldn't find PATH")]
    NoPATH,
    #[error("No command named '{0}' found in PATH")]
    NoCommand(String),
}

unsafe impl Send for BeaverRubyError {}

impl From<magnus::Error> for BeaverRubyError {
    fn from(value: magnus::Error) -> Self {
        // let backtrace = value.value().map_or("".to_string(), |value| value.funcall("backtrace", ())
        //     .map_or("".to_string(), |value: magnus::Value| {
        //         value.funcall("join", ("\n",))
        //             .map_or("".to_string(), |value: magnus::RString| {
        //                 match unsafe { value.as_str() } {
        //                     Ok(val) => "\n".to_string() + val,
        //                     Err(_) => "".to_string()
        //                 }
        //             })
        //     })
        // );

        let strerr = format!(
            "{}{}",
            value,
            // include a backtrace
            value.value().map_or("".to_string(), |value| value.funcall("backtrace", ())
                .map_or("".to_string(), |value: magnus::Value| {
                    value.funcall("join", ("\n",))
                        .map_or("".to_string(), |value: magnus::RString| {
                            match unsafe { value.as_str() } {
                                Ok(val) => "\n".to_string() + val,
                                Err(_) => "".to_string()
                            }
                        })
                    })
            )
        );

        BeaverRubyError::MagnusError(value, strerr)
    }
}

impl From<BeaverRubyError> for magnus::Error {
    fn from(value: BeaverRubyError) -> magnus::Error {
        let ruby = magnus::Ruby::get().unwrap();
        match value {
            BeaverRubyError::MagnusError(error, _) => error,
            BeaverRubyError::ArgumentError(argerrstr) => {
                let exc_class = ruby.exception_arg_error();
                magnus::Error::new(exc_class, argerrstr)
            },
            _ => {
                let exc_class = ruby.exception_runtime_error();
                magnus::Error::new(exc_class, value.to_string())
            }
        }
    }
}

pub type Result<T> = std::result::Result<T, BeaverRubyError>;
