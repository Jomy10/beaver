use std::time::Duration;

#[derive(thiserror::Error, Debug)]
pub enum SqlConversionError {
    #[error("Cannot construct system time from duration {0:?}")]
    SystemTimeFromDuration(Duration),
}
