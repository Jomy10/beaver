use std::ffi::OsString;

use beaver::{Beaver, OptimizationMode};
use clap::{arg, Arg, ArgAction, Command};
use lazy_static::lazy_static;

include!(concat!(env!("OUT_DIR"), "/rb_const_gen.rs"));

lazy_static! {
    static ref default_opt_mode: OsString = Into::<OsString>::into(OptimizationMode::Debug);
    static ref release_opt_mode: OsString = Into::<OsString>::into(OptimizationMode::Release);
}

fn main() {
    let matches = Command::new("beaver")
        .author("Jonas Everaert")
        .version(VERSION)
        .long_version(LONG_VERSION)
        .propagate_version(true)
        .about("Reliable, powerful build system")
        .arg(arg!([command] "The command to call (default: build)")) // TODO: as subcommand
        .arg(arg!(-f <FILE> "The path to the script file")
            .long("script-file"))
        .arg(arg!(-o --opt [OPT] "Optimization mode (`debug` or `release`)")
            .default_value(default_opt_mode.as_os_str())
            .default_missing_value(release_opt_mode.as_os_str())
            .long_help("Optimization mode (`debug` or `release`)
When the argument is provided, but without a value, then the optimization mode is set to release")
            .value_parser(["debug", "release"])
            .ignore_case(true))
        .arg(arg!(--color "Enable color output (default: automatic)"))
        .arg(Arg::new("no-color").long("no-color").action(ArgAction::SetTrue).hide(true))
        .arg(arg!([args] ... "arguments passed to the build script").trailing_var_arg(true))
        .get_matches();

    let flag_color = matches.get_flag("color");
    let flag_no_color = matches.get_flag("no-color");
    let color = if flag_color == false && flag_no_color == false { None } else { Some(flag_color || !flag_no_color) };

    let opt = OptimizationMode::try_from(matches.get_one::<String>("opt").unwrap().as_str()).unwrap();

    let beaver = Beaver::new(color, opt);

    dbg!(beaver);
}
