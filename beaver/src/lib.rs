#![feature(iter_intersperse, once_cell_try, error_generic_member_access, env_split_paths_ref, hasher_prefixfree_extras, once_lock_new_init)]
#![cfg_attr(target_os = "wasi", feature(wasi_ext))]

use utils::moduse;

pub mod backend;
pub(crate) mod platform;
pub(crate) mod cache;
pub(crate) mod triple;
pub(crate) mod path;
pub mod phase_hook;
pub mod command;
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
