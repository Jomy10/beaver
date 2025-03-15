#![cfg_attr(all(feature = "junctions", windows), feature(junction_point))]

#[macro_export]
macro_rules! moduse {
    ($modname:ident) => {
        mod $modname;
        pub use $modname::*;
    }
}

pub mod any;
pub mod str;
pub mod flags;
pub mod fs;
moduse!(which);
moduse!(unsafe_sendable);
