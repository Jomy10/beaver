use std::process::Command;
use std::{env, fs};
use std::path::Path;
use std::io;

use const_gen::{const_declaration, const_definition, CompileConst};

#[derive(CompileConst)]
#[inherit_doc]
/// Holds the ruby version determined by a build script
struct RubyVersion {
    major: u8,
    minor: u8,
    teeny: u8,
    patch: u8,
}

impl std::fmt::Display for RubyVersion {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_fmt(format_args!("Ruby v{}.{}.{}", self.major, self.minor, self.teeny))
    }
}

const VERSION: &'static str = "v4.0.0";

fn run_ruby(s: &str) -> String {
    let out = Command::new("ruby")
        .args(["-e", s])
        .output()
        .expect("Failed to run ruby")
    ;
    if !out.status.success() {
        println!("{:?}", out);
        panic!("Error: {}", String::from_utf8(out.stderr).unwrap_or("no stderr".to_string()));
    }
    return String::from_utf8(out.stdout).expect("Output is not valid utf8");
}

pub fn main() -> Result<(), Box<dyn std::error::Error>> {
    // Define constants //
    let out_dir = env::var_os("OUT_DIR").ok_or(io::Error::from(io::ErrorKind::NotFound))?;
    let dest_path = Path::new(&out_dir).join("rb_const_gen.rs");

    let major = run_ruby("require 'rbconfig'; puts RbConfig::CONFIG['MAJOR']")
        .chars().nth(0).unwrap().to_digit(10).unwrap() as u8;
    let minor = run_ruby("require 'rbconfig'; puts RbConfig::CONFIG['MINOR']")
        .chars().nth(0).unwrap().to_digit(10).unwrap() as u8;
    let teeny = run_ruby("require 'rbconfig'; puts RbConfig::CONFIG['TEENY']")
        .chars().nth(0).unwrap().to_digit(10).unwrap() as u8;
    let patch = run_ruby("require 'rbconfig'; puts RbConfig::CONFIG['PATCHLEVEL']")
            .chars().nth(0).unwrap().to_digit(10).unwrap() as u8;

    let ruby_version = RubyVersion { major, minor, teeny, patch };

    // long version shows both Beaver version and Ruby version and any other dynamic dependency versions
    let long_version = format!("{}\n{}", VERSION, ruby_version);
    let const_declartations = vec![
        const_definition!(#[derive(Debug)] #[allow(unused)] pub RubyVersion),
        const_declaration!(pub RUBY_VERSION = ruby_version),
        const_declaration!(pub VERSION = VERSION),
        const_declaration!(pub LONG_VERSION = long_version),
    ].join("\n");

    fs::write(&dest_path, const_declartations)?;

    // TODO: Generate manpages

    return Ok(());
}
