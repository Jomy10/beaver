//! Triples are not always the same across build systems and languages.
//! `TripleExt` provides utility functions to format a triple to a string, for a given build system/language.

use target_lexicon::Triple;

pub trait TripleExt {
    fn swift_name(&self) -> String;
}

impl TripleExt for Triple {
    // TODO: incomplete
    fn swift_name(&self) -> String {
        let str = self.to_string();
        match str.as_str() {
            "aarch64-apple-darwin" => "arm64-apple-macosx".to_string(),
            _ => str
        }
    }
}
