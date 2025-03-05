
use lazy_static::lazy_static;

use crate::tools;

use super::{Pool, Rule};

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
            ],
            pool: None
        }
    };

    static ref LINK_CMD: String = format!("{} $linkerFlags $in -o $out", tools::cc.display());
    pub static ref LINK: Rule = {
        Rule {
            name: "link",
            options: vec![
                ("description", "linking $out"),
                ("command", &LINK_CMD),
            ],
            pool: None
        }
    };

    static ref AR_CMD: String = format!("{} -rc $out $in", tools::ar.display());
    pub static ref AR: Rule = {
        Rule {
            name: "ar",
            options: vec![
                ("description", "creating $out"),
                ("command", &AR_CMD)
            ],
            pool: None
        }
    };

    static ref NINJA_POOL: Pool = {
        Pool {
            name: "ninja_pool",
            depth: 1
        }
    };

    // TODO: check ninja version -> if >= 1.1, enable pools
    static ref NINJA_CMD: String = format!("{} -C $ninjaBaseDir -f $ninjaFile $targets", tools::ninja.display());
    pub static ref NINJA: Rule = {
        Rule {
            name: "ninja",
            options: vec![
                ("description", "building $targets"),
                ("command", &NINJA_CMD),
            ],
            pool: Some(&NINJA_POOL)
        }
    };
}
