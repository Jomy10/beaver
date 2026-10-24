#[derive(Debug, PartialEq, Clone, Copy)]
pub enum CStd {
    C89,
    C90,
    C95,
    C99,
    C11,
    C17,
    C23,
    C2Y,

    Gnu89,
    Gnu90,
    Gnu99,
    Gnu11,
    Gnu17,
    Gnu23,
    Gnu2Y
}

impl CStd {
    pub fn from_year_and_ext(year: u32, ext: bool) -> CStd {
        match year {
            1989 => if ext { CStd::Gnu89 } else { CStd::C89 },
            1990 => if ext { CStd::Gnu90 } else { CStd::C90 },
            1995 => CStd::C95,
            1999 => if ext { CStd::Gnu99 } else { CStd::C99 },
            2011 => if ext { CStd::Gnu11 } else { CStd::C11 },
            2017 => if ext { CStd::Gnu17 } else { CStd::C17 },
            2023 => if ext { CStd::Gnu23 } else { CStd::C23 },
            2025 => if ext { CStd::Gnu2Y } else { CStd::C2Y },
            _ => panic!("Unknown C std: {year}{}", if ext { " gnu extensions" } else { "" }),
        }
    }

    pub fn parse(value: &str) -> Option<Self> {
        Some(match value {
            "c89" => Self::C89,
            "c90" | "iso9899:1990" => Self::C90,
            "iso9899:199409" => Self::C95,
            "c99" | "iso9899:1999" => Self::C99,
            "c11" | "iso9899:2011" => Self::C11,
            "c17" | "iso9899:2017" => Self::C17,
            "c23" | "iso9899:2024" => Self::C23,
            "c2y" => Self::C2Y,

            "gnu89" => Self::Gnu89,
            "gnu90" => Self::Gnu90,
            "gnu99" => Self::Gnu99,
            "gnu11" => Self::Gnu11,
            "gnu17" => Self::Gnu17,
            "gnu23" => Self::Gnu23,
            "gnu2y" => Self::Gnu2Y,

            _ => return None,
        })
    }

    pub const fn as_str(&self) -> &'static str {
        match self {
            Self::C89 => "c89",
            Self::C90 => "c90",
            Self::C95 => "iso9899:199409",
            Self::C99 => "c99",
            Self::C11 => "c11",
            Self::C17 => "c17",
            Self::C23 => "c23",
            Self::C2Y => "c2y",

            Self::Gnu89 => "gnu89",
            Self::Gnu90 => "gnu90",
            Self::Gnu99 => "gnu99",
            Self::Gnu11 => "gnu11",
            Self::Gnu17 => "gnu17",
            Self::Gnu23 => "gnu23",
            Self::Gnu2Y => "gnu2y",
        }
    }

    pub fn is_gnu_ext(&self) -> bool {
        match self {
            CStd::C89 | CStd::C90 | CStd::C95 | CStd::C99 |
            CStd::C11 | CStd::C17 | CStd::C23 | CStd::C2Y => false,
            CStd::Gnu89 | CStd::Gnu90 | CStd::Gnu99 | CStd::Gnu11 |
            CStd::Gnu17 | CStd::Gnu23 | CStd::Gnu2Y => true
        }
    }

    fn year(&self) -> u32 {
        match self {
            CStd::C89 | CStd::Gnu89 => 1998,
            CStd::C90 | CStd::Gnu90 => 1998,
            CStd::C95 => 1995,
            CStd::C99 | CStd::Gnu99 => 1999,
            CStd::C11 | CStd::Gnu11 => 2011,
            CStd::C17 | CStd::Gnu17 => 2017,
            CStd::C23 | CStd::Gnu23 => 2023,
            CStd::C2Y | CStd::Gnu2Y => 9999
        }
    }

    pub fn max(&self, other: &Self) -> Self {
        let year = if self.year() > other.year() { self.year() } else { other.year() };
        let gnu = self.is_gnu_ext() || other.is_gnu_ext();
        return Self::from_year_and_ext(year, gnu);
    }
}

#[derive(Debug, PartialEq, Clone, Copy)]
pub enum CxxStd {
    Cxx98,
    Cxx03,
    Cxx11,
    Cxx14,
    Cxx17,
    Cxx20,
    Cxx23,
    Cxx26, // draft
    Cxx29, // draft

    Gnuxx98,
    Gnuxx03,
    Gnuxx11,
    Gnuxx14,
    Gnuxx17,
    Gnuxx20,
    Gnuxx23,
    Gnuxx26,
    Gnuxx29
}

impl CxxStd {
    pub fn from_year_and_ext(year: u32, ext: bool) -> CxxStd {
        match year {
            1998 => if ext { CxxStd::Gnuxx98 } else { CxxStd::Cxx98 },
            2003 => if ext { CxxStd::Gnuxx03 } else { CxxStd::Cxx03 },
            2011 => if ext { CxxStd::Gnuxx11 } else { CxxStd::Cxx11 },
            2014 => if ext { CxxStd::Gnuxx14 } else { CxxStd::Cxx14 },
            2017 => if ext { CxxStd::Gnuxx17 } else { CxxStd::Cxx17 },
            2020 => if ext { CxxStd::Gnuxx20 } else { CxxStd::Cxx20 },
            2023 => if ext { CxxStd::Gnuxx23 } else { CxxStd::Cxx23 },
            2026 => if ext { CxxStd::Gnuxx26 } else { CxxStd::Cxx26 },
            2029 => if ext { CxxStd::Gnuxx29 } else { CxxStd::Cxx29 },
            _ => panic!("Unknown C++ std: {year}{}", if ext { " gnu extensions" } else { "" }),
        }
    }

    pub fn parse(value: &str) -> Option<Self> {
        Some(match value {
            "c++98" => Self::Cxx98,
            "c++03" => Self::Cxx03,
            "c++11" => Self::Cxx11,
            "c++14" => Self::Cxx14,
            "c++17" => Self::Cxx17,
            "c++20" => Self::Cxx20,
            "c++23" => Self::Cxx23,
            "c++2c" | "c++26" => Self::Cxx26,
            "c++2d" | "c++29" => Self::Cxx29,

            "gnu++98" => Self::Gnuxx98,
            "gnu++03" => Self::Gnuxx03,
            "gnu++11" => Self::Gnuxx11,
            "gnu++14" => Self::Gnuxx14,
            "gnu++17" => Self::Gnuxx17,
            "gnu++20" => Self::Gnuxx20,
            "gnu++23" => Self::Gnuxx23,
            "gnu++2c" | "gnu++26" => Self::Gnuxx26,
            "gnu++2d" | "gnu++29" => Self::Gnuxx29,

            _ => return None,
        })
    }

    pub const fn as_str(&self) -> &'static str {
        match self {
            Self::Cxx98 => "c++98",
            Self::Cxx03 => "c++03",
            Self::Cxx11 => "c++11",
            Self::Cxx14 => "c++14",
            Self::Cxx17 => "c++17",
            Self::Cxx20 => "c++20",
            Self::Cxx23 => "c++23",
            Self::Cxx26 => "c++2c",
            Self::Cxx29 => "c++2d",

            Self::Gnuxx98 => "gnu++98",
            Self::Gnuxx03 => "gnu++03",
            Self::Gnuxx11 => "gnu++11",
            Self::Gnuxx14 => "gnu++14",
            Self::Gnuxx17 => "gnu++17",
            Self::Gnuxx20 => "gnu++20",
            Self::Gnuxx23 => "gnu++23",
            Self::Gnuxx26 => "gnu++2c",
            Self::Gnuxx29 => "gnu++2d",
        }
    }

    pub fn is_gnu_ext(&self) -> bool {
        match self {
            CxxStd::Cxx98 | CxxStd::Cxx03 | CxxStd::Cxx11 | CxxStd::Cxx14 |
            CxxStd::Cxx17 | CxxStd::Cxx20 | CxxStd::Cxx23 | CxxStd::Cxx26 |
            CxxStd::Cxx29 => false,
            CxxStd::Gnuxx98 | CxxStd::Gnuxx03 | CxxStd::Gnuxx11 | CxxStd::Gnuxx14 |
            CxxStd::Gnuxx17 | CxxStd::Gnuxx20 | CxxStd::Gnuxx23 | CxxStd::Gnuxx26 |
            CxxStd::Gnuxx29 => false,
        }
    }

    fn year(&self) -> u32 {
        match self {
            CxxStd::Cxx98 | CxxStd::Gnuxx98 => 1998,
            CxxStd::Cxx03 | CxxStd::Gnuxx03 => 2003,
            CxxStd::Cxx11 | CxxStd::Gnuxx11 => 2011,
            CxxStd::Cxx14 | CxxStd::Gnuxx14 => 2014,
            CxxStd::Cxx17 | CxxStd::Gnuxx17 => 2017,
            CxxStd::Cxx20 | CxxStd::Gnuxx20 => 2020,
            CxxStd::Cxx23 | CxxStd::Gnuxx23 => 2023,
            CxxStd::Cxx26 | CxxStd::Gnuxx26 => 2026,
            CxxStd::Cxx29 | CxxStd::Gnuxx29 => 2029,
        }
    }

    pub fn max(&self, other: &Self) -> Self {
        let year = if self.year() > other.year() { self.year() } else { other.year() };
        let gnu = self.is_gnu_ext() || other.is_gnu_ext();
        return Self::from_year_and_ext(year, gnu);
    }
}
