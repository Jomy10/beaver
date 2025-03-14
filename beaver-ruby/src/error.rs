use std::num::{ParseFloatError, ParseIntError};
use std::rc::Rc;
use std::str::ParseBoolError;

use magnus::error::RubyUnavailableError;
use magnus::value::ReprValue;

use crate::{BeaverRubyContext, CTX_RC};

#[derive(Debug, thiserror::Error)]
pub enum BeaverRubyError {
    #[error(transparent)]
    RubyUnavailableError(#[from] RubyUnavailableError),
    #[error("{}{}",
        .0,
        // include a backtrace
        .0.value().map_or("".to_string(), |value| value.funcall("backtrace", ())
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
    )]
    MagnusError(magnus::Error, Rc<BeaverRubyContext>), // The BeaverRubyContext should be kept alive so we can construct the backtrace
    #[error("IO Error: {0}")]
    IOError(#[from] std::io::Error),
    #[error(transparent)]
    BeaverError(#[from] beaver::BeaverError),
    #[error("Cannot convert {0} to {1}", )]
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
}

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

        BeaverRubyError::MagnusError(
            value,
            #[allow(static_mut_refs)]
            unsafe { CTX_RC.assume_init_ref().upgrade().expect("Rc was dropped") }
        )
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
