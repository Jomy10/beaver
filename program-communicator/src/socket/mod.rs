use utils::moduse;

#[cfg(unix)]
pub mod unix;

moduse!(wrapper);

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum ReceiveResult {
    Close,
    /// Continue listening
    Continue
}
