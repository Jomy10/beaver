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
moduse!(which);
