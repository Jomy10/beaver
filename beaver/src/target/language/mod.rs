use log::warn;
use target_lexicon::Triple;

pub(crate) mod objc;
mod swift;
mod cxx;
#[cfg(target_os = "macos")]
mod darwin;

#[derive(Clone, Copy, PartialEq, Eq, Debug, Hash)]
pub enum Language {
    C,
    CXX,
    OBJC,
    OBJCXX,

    Rust,
    Swift,
}

impl Language {
    pub fn parse(s: &str) -> Option<Self> {
        match s.to_uppercase().as_str() {
            "C" => Some(Self::C),
            "CXX" | "C++" | "CPP" => Some(Self::CXX),
            "OBJ-C" | "OBJC" => Some(Self::OBJC),
            "OBJ-CXX" | "OBJ-CPP" | "OBJ-C++" |
            "OBJCXX" | "OBJCPP" | "OBJC++" => Some(Self::OBJCXX),
            _ => None
        }
    }

    pub fn cflags(from: Language, to: Language) -> Option<&'static [&'static str]> {
        use Language::*;

        match (from, to) {
            (OBJC, _) => None,
            (OBJCXX, _) => None,
            // (OBJC, _) => Some(*OBJC_CFLAGS),
            // (OBJCXX, _) => Some(*OBJCXX_CFLAGS),
            (C, _) => None,
            (CXX, _) => None,
            (Rust, _) => None,
            (Swift, _) => None,
        }
    }

    pub fn linker_flags(from: Language, to: Language, target: &Triple) -> Option<&'static [&'static str]> {
        use Language::*;

        match (from, to) {
            (C, _) => None,

            (CXX, C | OBJC) | (OBJCXX, OBJC) => Some(&cxx::CXX_TO_C_LINKER_FLAGS),
            (CXX, CXX | OBJCXX) => None,
            (CXX, Rust | Swift) => None,

            (OBJC, CXX | C) => Some(objc::objc_cflags()),
            (OBJCXX, CXX) => Some(objc::objcxx_linker_flags()),
            (OBJCXX, C) => Some(objc::OBJCXX_TO_C_LINKER_FLAGS.as_slice()),
            (OBJC, OBJC | OBJCXX) |
            (OBJCXX, OBJCXX) => None,

            (OBJCXX | OBJC, Rust | Swift) => None,

            (Rust, _) => None,

            (Swift, Swift) => None,
            (Swift, _) => {
                if target.operating_system.is_like_darwin() {
                    Some(swift::swift_linker_flags(target))
                } else {
                    warn!("Swift linking may not be currently working for {}", target);
                    None
                }
            },
        }
    }
}
