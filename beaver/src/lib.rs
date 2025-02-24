use utils::moduse;

pub mod backend;
pub(crate) mod platform;
pub mod project;
pub mod target;
moduse!(beaver);
moduse!(error);
moduse!(optimization_mode);

pub mod traits {
    pub use crate::project::traits::*;
    pub use crate::target::traits::*;
}
