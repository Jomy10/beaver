use lazy_static::lazy_static;

use super::Rule;

lazy_static! {
    pub static ref CC: Rule = {
        Rule {
            name: "cc".to_string(),
            options: vec![
                ("description".to_string(), "cc $in > $out".to_string()),
                ("command".to_string(), "cc $cflags -MD -MF $out.d -c $in -o $out".to_string()), // TODO!
                ("deps".to_string(), "gcc".to_string()),
                ("depfile".to_string(), "$out.d".to_string())
            ]
        }
    };

    pub static ref LINK: Rule = {
        Rule {
            name: "link".to_string(),
            options: vec![
                ("description".to_string(), "linking $out".to_string()),
                ("command".to_string(), "cc $linkerFlags $in -o $out".to_string()), // TODO!
            ]
        }
    };
}
