use std::fmt::format;

use lazy_static::lazy_static;

use crate::tools;

use super::Rule;

lazy_static! {
    static ref CC_CMD: String = format!("{} $cflags -MD -MF $out.d -c $in -o $out", tools::cc.display());
    pub static ref CC: Rule = {
        Rule {
            name: "cc",
            options: vec![
                ("description", "cc $in > $out"),
                ("command", &CC_CMD),
                ("deps", "gcc"),
                ("depfile", "$out.d")
            ]
        }
    };

    static ref LINK_CMD: String = format!("{} $linkerFlags $in -o $out", tools::cc.display());
    pub static ref LINK: Rule = {
        Rule {
            name: "link",
            options: vec![
                ("description", "linking $out"),
                ("command", &LINK_CMD),
            ]
        }
    };

    static ref AR_CMD: String = format!("{} -rc $out $in", tools::ar.display());
    pub static ref AR: Rule = {
        Rule {
            name: "ar",
            options: vec![
                ("description", "creating $out"),
                ("command", &AR_CMD)
            ]
        }
    };
}
