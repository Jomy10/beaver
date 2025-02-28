use std::process::Command;

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
    let libdir = run_ruby("require 'rbconfig'; puts RbConfig::CONFIG['libdir']");
    let so = run_ruby("require 'rbconfig'; puts RbConfig::CONFIG['RUBY_SO_NAME']");

    println!("cargo::rustc-link-search={}", libdir);
    println!("cargo::rustc-link-lib={}", so);

    return Ok(());
}
