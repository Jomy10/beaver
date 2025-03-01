use lazy_static::lazy_static;

use super::Rule;

lazy_static! {
    pub static ref CC: Rule = {
        Rule {
            name: "cc",
            options: vec![
                ("description", "cc $in > $out"),
                ("command", "cc $cflags -MD -MF $out.d -c $in -o $out"), // TODO!
                ("deps", "gcc"),
                ("depfile", "$out.d")
            ]
        }
    };

    pub static ref LINK: Rule = {
        Rule {
            name: "link",
            options: vec![
                ("description", "linking $out"),
                ("command", "cc $linkerFlags $in -o $out"), // TODO!
            ]
        }
    };

    pub static ref AR: Rule = {
        Rule {
            name: "ar",
            options: vec![
                ("description", "creating $out"),
                ("command", "ar -rc $out $in")
            ]
        }
    };
}
