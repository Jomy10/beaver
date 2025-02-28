#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum Language {
    C,
    CXX,
    OBJC,
    OBJCXX
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
}
