#![feature(iter_intersperse, once_cell_try, error_generic_member_access, )]

use utils::moduse;

pub mod backend;
pub(crate) mod platform;
pub(crate) mod cache;
pub mod project;
pub mod target;
pub mod tools;
moduse!(beaver);
moduse!(error);
moduse!(optimization_mode);

pub mod traits {
    pub use crate::project::traits::*;
    pub use crate::target::traits::*;
}
