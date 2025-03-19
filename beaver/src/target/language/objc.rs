use lazy_static::lazy_static;

#[cfg(target_os = "macos")]
pub(crate) mod darwin {
    lazy_static::lazy_static! {
        // only for compiling objc itself
        pub static ref OBJC_CFLAGS: &'static [&'static str] = &["-x", "objective-c", "-fobjc-arc", "-fmodules"];
        pub static ref OBJCXX_CFLAGS: &'static [&'static str] = &["-x", "objective-c++", "-fobjc-arc", "-fmodules"];
        pub static ref OBJC_LINKER_FLAGS: &'static [&'static str] = &["-lobjc"];
        pub static ref OBJCXX_LINKER_FLAGS: &'static [&'static str] = &["-lobjc"];
    }

    #[inline]
    pub fn objc_cflags() -> &'static [&'static str] {
        &*OBJC_CFLAGS
    }

    #[inline]
    pub fn objcxx_cflags() -> &'static [&'static str] {
        &*OBJCXX_CFLAGS
    }

    #[inline]
    pub fn objc_linker_flags() -> &'static [&'static str] {
        &*OBJC_LINKER_FLAGS
    }

    #[inline]
    pub fn objcxx_linker_flags() -> &'static [&'static str] {
        &*OBJCXX_LINKER_FLAGS
    }
}

#[cfg(not(target_os = "macos"))]
pub(crate) mod other {
    use std::process::Command;

    use crate::tools;

    lazy_static::lazy_static! {
        static ref OBJC_CFLAGS: Vec<String> = {
            let output = Command::new(tools::gnustep_config.as_path())
                .args(["--objc-flags"])
                .output()
                .expect("Failed to get objc-flags from gnustep-config")
                .stdout;

            shlex::bytes::Shlex::new(output.as_slice())
                .map(|arg| String::from_utf8(arg).expect("Invalid UTF-8"))
                .collect()
        };
        static ref OBJC_CFLAGS_REF: Vec<&'static str> = OBJC_CFLAGS.iter().map(|str| str.as_str()).collect();

        static ref OBJC_LINKER_FLAGS: Vec<String> = {
            let output = Command::new(tools::gnustep_config.as_path())
                .args(["--objc-libs", "--base-libs"])
                .output()
                .expect("Failed to get objc-libs from gnustep-config")
                .stdout;

            shlex::bytes::Shlex::new(output.as_slice())
                .map(|arg| String::from_utf8(arg).expect("Invalid UTF-8"))
                .collect()
        };
        static ref OBJC_LINKER_FLAGS_REF: Vec<&'static str> = OBJC_LINKER_FLAGS.iter().map(|str| str.as_str()).collect();
    }

    #[inline]
    pub fn objc_cflags() -> &'static [&'static str] {
        &OBJC_CFLAGS_REF
    }

    #[inline]
    pub fn objcxx_cflags() -> &'static [&'static str] {
        objc_cflags()
    }

    #[inline]
    pub fn objc_linker_flags() -> &'static [&'static str] {
        &OBJC_LINKER_FLAGS_REF
    }

    #[inline]
    pub fn objcxx_linker_flags() -> &'static [&'static str] {
        objc_linker_flags()
    }
}

#[cfg(target_os = "macos")]
pub use darwin::*;
#[cfg(not(target_os = "macos"))]
pub use other::*;

lazy_static! {
    pub static ref OBJCXX_TO_C_LINKER_FLAGS: Vec<&'static str> = {
        let mut flags = super::cxx::CXX_TO_C_LINKER_FLAGS.to_vec();
        flags.extend(objcxx_linker_flags().iter());
        return flags;
    };
}
