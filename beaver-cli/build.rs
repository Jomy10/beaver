use std::{env, fs};
use std::path::Path;

use const_gen::{const_declaration, const_definition, CompileConst};

#[derive(CompileConst)]
#[inherit_doc]
struct RubyVersion {
    major: u8,
    minor: u8,
    patch: u8
}

impl std::fmt::Display for RubyVersion {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_fmt(format_args!("Ruby v{}.{}.{}", self.major, self.minor, self.patch))
    }
}

const VERSION: &'static str = "v4.0.0";

pub fn main() -> Result<(), Box<dyn std::error::Error>> {
    let rb_env = rb_sys_env::load()?; // we don't need to activate since that is done by rutie

    let out_dir = env::var_os("OUT_DIR").unwrap();
    let dest_path = Path::new(&out_dir).join("rb_const_gen.rs");

    let rbver = rb_env.ruby_version();
    let ruby_version = RubyVersion {
        major: rbver.major(),
        minor: rbver.minor(),
        patch: rbver.teeny(),
    };
    // long version shows both Beaver version and Ruby version and any other dynamic dependency versions
    let long_version = format!("{}\n{}", VERSION, ruby_version);
    let const_declartations = vec![
        const_definition!(#[derive(Debug)] pub RubyVersion),
        const_declaration!(pub RUBY_VERSION = ruby_version),
        const_declaration!(pub VERSION = VERSION),
        const_declaration!(pub LONG_VERSION = long_version),
    ].join("\n");

    fs::write(&dest_path, const_declartations)?;

    return Ok(());
}
