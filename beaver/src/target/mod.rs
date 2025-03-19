use crate::moduse;

pub mod traits;
pub mod parameters;
moduse!(version);
pub mod language;
pub use language::Language;
moduse!(artifact);
moduse!(dependency);
moduse!(targets);
