use std::ffi::OsString;
use std::path::Path;

use beaver::{Beaver, OptimizationMode};
use clap::{arg, Arg, ArgAction, Command, ValueHint};
use lazy_static::lazy_static;
use log::warn;

include!(concat!(env!("OUT_DIR"), "/rb_const_gen.rs"));

lazy_static! {
    static ref default_opt_mode: OsString = Into::<OsString>::into(OptimizationMode::Debug);
    static ref release_opt_mode: OsString = Into::<OsString>::into(OptimizationMode::Release);
}

fn main() {
    let mut clog = colog::default_builder();
    clog.filter(None, log::LevelFilter::Trace);
    clog.init();

    let matches = Command::new("beaver")
        .author("Jonas Everaert")
        .version(VERSION)
        .long_version(LONG_VERSION)
        .propagate_version(true)
        .about("Reliable, powerful build system")
        .arg(arg!([command] "The command to call (default: build)")) // TODO: as subcommand
        .arg(Arg::new("script-file")
            .short('f')
            .value_name("FILE")
            .value_hint(ValueHint::FilePath)
            .long("script-file")
            .help("The path to the script file"))
        .arg(arg!(-o --opt [OPT] "Optimization mode")
            .default_value(default_opt_mode.as_os_str())
            .default_missing_value(release_opt_mode.as_os_str())
            .long_help("Optimization mode
When the argument is provided, but without a value, then the optimization mode is set to release")
            .value_parser(["debug", "release"])
            .ignore_case(true))
        .arg(arg!(--color "Enable color output (default: automatic)"))
        .arg(Arg::new("no-color").long("no-color").action(ArgAction::SetTrue).hide(true))
        .arg(arg!([args] ... "arguments passed to the build script").trailing_var_arg(true))
        .get_matches();

    let flag_color = matches.get_flag("color");
    let flag_no_color = matches.get_flag("no-color");
    if flag_color == true && flag_no_color == true { warn!("Both --color and --no-color are specified. --color will get priority") };
    let color = if flag_color == false && flag_no_color == false { None } else { Some(flag_color || !flag_no_color) };

    let opt = OptimizationMode::try_from(matches.get_one::<String>("opt").unwrap().as_str()).unwrap();

    let filenames = ["beaver.rb", "Beaverfile", "build.rb", "make.rb"];
    let script_file = match matches.get_one::<String>("script-file") {
        Some(file) => Path::new(file),
        None => {
            let filename = filenames.iter().find(|filename| {
                let path = Path::new(filename);
                path.exists()
            });
            let Some(filename) = filename else {
                panic!("Couldn't find a beaver script file in the current directory. Possible filenames are {}. Alternatively you can specify the filename using `--file <FILE>`", filenames.map(|filename| format!("'{}'", filename)).join(", "))
            };
            Path::new(filename)
        }
    };

    let beaver = Beaver::new(color, opt);
    let rb_context = match beaver_ruby::execute(beaver, script_file) {
        Err(err) => panic!("{}", err),
        Ok(ctx) => ctx,
    };

    dbg!(&rb_context.context);
    drop(rb_context); // needs to live as long as beaver
}
