use utils::moduse;

pub(crate) mod backend;
pub(crate) mod platform;
pub mod project;
pub mod target;
moduse!(error);
moduse!(beaver);
moduse!(optimization_mode);

pub mod preface {
    pub mod traits {
        pub use crate::project::traits::*;
        pub use crate::target::traits::*;
    }

    pub mod c {
        pub use crate::project::c::*;
        pub use crate::target::c::*;
    }
}
