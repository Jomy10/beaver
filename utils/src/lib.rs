#[macro_export]
macro_rules! moduse {
    ($modname:ident) => {
        mod $modname;
        pub use $modname::*;
    }
}
