
use lazy_static::lazy_static;

use crate::tools;

use super::{Pool, Rule};

lazy_static! {
    static ref CC_CMD: String = format!("{} {} $cflags -MD -MF $out.d -c $in -o $out", tools::cc.display(), tools::cc_extra_args.map(|a| a.join(" ")).unwrap_or("".to_string()));
    pub static ref CC: Rule = Rule {
        name: "cc",
        options: vec![
            ("description", "cc $in > $out"),
            ("command", &CC_CMD),
            ("deps", "gcc"),
            ("depfile", "$out.d")
        ],
        pool: None
    };

    static ref CXX_CMD: String = format!("{} {} $cflags -MD -MF $out.d -c $in -o $out", tools::cxx.display(), tools::cxx_extra_args.map(|a| a.join(" ")).unwrap_or("".to_string()));
    pub static ref CXX: Rule = Rule {
        name: "cxx",
        options: vec![
            ("description", "cxx $in > $out"),
            ("command", &CXX_CMD),
            ("deps", "gcc"),
            ("depfile", "$out.d")
        ],
        pool: None
    };

    static ref OBJC_CMD: String = format!("{} $cflags -MD -MF $out.d -c $in -o $out", tools::objc.display());
    pub static ref OBJC: Rule = Rule {
        name: "objc",
        options: vec![
            ("description", "objc $in > $out"),
            ("command", &OBJC_CMD),
            ("deps", "gcc"),
            ("depfile", "$out.d")
        ],
        pool: None
    };

    static ref OBJCXX_CMD: String = format!("{} $cflags -MD -MF $out.d -c $in -o $out", tools::objcxx.display());
    pub static ref OBJCXX: Rule = Rule {
        name: "objcxx",
        options: vec![
            ("description", "objcxx $in > $out"),
            ("command", &OBJCXX_CMD),
            ("deps", "gcc"),
            ("depfile", "$out.d")
        ],
        pool: None
    };

    static ref LINK_CMD: String = format!("{} $linkerFlags $in -o $out", tools::cc.display());
    pub static ref LINK: Rule = Rule {
        name: "link",
        options: vec![
            ("description", "linking $out"),
            ("command", &LINK_CMD),
        ],
        pool: None
    };

    static ref LINKXX_CMD: String = format!("{} $linkerFlags $in -o $out", tools::cxx.display());
    pub static ref LINKXX: Rule = Rule {
        name: "linkxx",
        options: vec![
            ("description", "linking $out"),
            ("command", &LINKXX_CMD),
        ],
        pool: None
    };

    static ref AR_CMD: String = format!("{} -rc $out $in", tools::ar.display());
    pub static ref AR: Rule = Rule {
        name: "ar",
        options: vec![
            ("description", "creating $out"),
            ("command", &AR_CMD)
        ],
        pool: None
    };

    /// Pool for external build systems
    static ref EXTERNAL_POOL: Pool = Pool {
        name: "external_build_pool",
        depth: 1
    };

    // TODO: check ninja version -> if >= 1.1, enable pools
    static ref NINJA_CMD: String = format!("{} -C $ninjaBaseDir -f $ninjaFile $targets", tools::ninja.display());
    pub static ref NINJA: Rule = Rule {
        name: "ninja",
        options: vec![
            ("description", "building $targets"),
            ("command", &NINJA_CMD),
        ],
        pool: Some(&EXTERNAL_POOL)
    };

    static ref CARGO_CMD: String = format!("cd $workspaceDir && cargo build $cargoArgs --package $target");
    pub static ref CARGO: Rule = Rule {
        name: "cargo",
        options: vec![
            ("description", "building $target"),
            ("command", &CARGO_CMD)
        ],
        pool: Some(&EXTERNAL_POOL),
    };

    // TODO: --artifact-dir <-- unstable
    static ref CARGO_WORKSPACE_CMD: String = format!("cd $workspaceDir && cargo build $cargoArgs --workspace");
    pub static ref CARGO_WORKSPACE: Rule = Rule {
        name: "cargo_build_workspace",
        options: vec![
            ("description", "building cargo workspace $workspaceDir"),
            ("command", &CARGO_WORKSPACE_CMD),
        ],
        pool: Some(&EXTERNAL_POOL),
    };
}
