use utils::moduse;

#[cfg(unix)]
pub mod unix;

moduse!(wrapper);
