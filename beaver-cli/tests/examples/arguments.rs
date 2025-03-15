use std::process::Command;

#[test]
fn opt() {
    let dir = super::example_dir("arguments");
    let output = Command::new(crate::beaver())
        .args(["printArg", "--", "--argument-name", "sdl-version", "--sdl-version", "3"])
        .current_dir(dir)
        .output()
        .unwrap();

    assert_eq!(output.status.code(), Some(0));
    assert_eq!(String::from_utf8(output.stdout).unwrap(), "3\n");
}

#[test]
fn opt_short() {
    let dir = super::example_dir("arguments");
    let output = Command::new(crate::beaver())
        .args(["printArg", "--", "--argument-name", "sdl-version", "-s", "3"])
        .current_dir(dir)
        .output()
        .unwrap();

    assert_eq!(output.status.code(), Some(0));
    assert_eq!(String::from_utf8(output.stdout).unwrap(), "3\n");
}

#[test]
fn opt_default() {
    let dir = super::example_dir("arguments");
    let output = Command::new(crate::beaver())
        .args(["printArg", "--", "--argument-name", "sdl-version"])
        .current_dir(dir)
        .output()
        .unwrap();

    assert_eq!(output.status.code(), Some(0));
    assert_eq!(String::from_utf8(output.stdout).unwrap(), "2\n");
}

#[test]
fn flag() {
    let dir = super::example_dir("arguments");
    let output = Command::new(crate::beaver())
        .args(["printArg", "--", "--argument-name", "from-source", "--from-source"])
        .current_dir(dir)
        .output()
        .unwrap();

    assert_eq!(output.status.code(), Some(0));
    assert_eq!(String::from_utf8(output.stdout).unwrap(), "true\n");
}

#[test]
fn flag_default() {
    let dir = super::example_dir("arguments");
    let output = Command::new(crate::beaver())
        .args(["printArg", "--", "--argument-name", "from-source"])
        .current_dir(dir)
        .output()
        .unwrap();

    assert_eq!(output.status.code(), Some(0));
    assert_eq!(String::from_utf8(output.stdout).unwrap(), "false\n");
}

#[test]
fn flag_nil_default() {
    let dir = super::example_dir("arguments");
    let output = Command::new(crate::beaver())
        .args(["printArg", "--", "--argument-name", "warn"])
        .current_dir(dir)
        .output()
        .unwrap();

    assert_eq!(output.status.code(), Some(0));
    assert_eq!(String::from_utf8(output.stdout).unwrap(), "\n");
}

#[test]
fn flag_nil_present() {
    let dir = super::example_dir("arguments");
    let output = Command::new(crate::beaver())
        .args(["printArg", "--", "--argument-name", "warn", "--warn"])
        .current_dir(dir)
        .output()
        .unwrap();

    assert_eq!(output.status.code(), Some(0));
    assert_eq!(String::from_utf8(output.stdout).unwrap(), "true\n");
}

#[test]
fn flag_nil_negated() {
    let dir = super::example_dir("arguments");
    let output = Command::new(crate::beaver())
        .args(["printArg", "--", "--argument-name", "warn", "--no-warn"])
        .current_dir(dir)
        .output()
        .unwrap();

    assert_eq!(output.status.code(), Some(0));
    assert_eq!(String::from_utf8(output.stdout).unwrap(), "false\n");
}

#[test]
fn cmd() {
    let dir = super::example_dir("arguments");
    let output = Command::new(crate::beaver())
        .args(["helloWorld"])
        .current_dir(dir)
        .output()
        .unwrap();

    assert_eq!(output.status.code(), Some(0));
    assert_eq!(String::from_utf8(output.stdout).unwrap(), "Hello world\n");
}

#[test]
fn cmd_shell() {
    let dir = super::example_dir("arguments");
    let output = Command::new(crate::beaver())
        .args(["shellCommand"])
        .current_dir(dir)
        .output()
        .unwrap();

    assert_eq!(output.status.code(), Some(0));
    assert_eq!(String::from_utf8(output.stdout).unwrap(), "Hello world!\nHello world!\n");
    assert!(output.stderr.len() > 1);
}
