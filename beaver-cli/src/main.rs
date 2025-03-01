use std::ffi::OsString;
use std::path::Path;

use beaver::target::TargetRef;
use beaver::{Beaver, OptimizationMode};
use clap::{arg, Arg, ArgAction, ArgMatches, Command, ValueHint};
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
        .arg(Arg::new("script-file")
            .short('f')
            .value_name("FILE")
            .value_hint(ValueHint::FilePath)
            .long("script-file")
            .help("The path to the script file"))
        .arg(arg!(-o --opt [OPT] "Optimization mode")
            .default_value(default_opt_mode.as_os_str())
            .default_missing_value(release_opt_mode.as_os_str())
            .value_hint(ValueHint::Other)
            .long_help("Optimization mode
When the argument is provided, but without a value, then the optimization mode is set to release")
            .value_parser(["debug", "release"])
            .ignore_case(true))
        .arg(arg!(--color "Enable color output (default: automatic)"))
        .arg(Arg::new("no-color").long("no-color").action(ArgAction::SetTrue).hide(true))
        .arg(arg!([targets]... "Target(s) to build")
            .long_help("Target(s) to build\nWhen no targets are passed, all targets in the current project are built."))
        .arg(arg!([args]... "Arguments passed to the build script")
            .required(false)
            .last(true))
        .subcommand(Command::new("list")
            .about("List projects and targets from the script file"))
        .subcommand(Command::new("clean")
            .about("Clean the project"))
        .subcommand(Command::new("run")
            .about("Build and run an executable target")
            .arg(arg!([target] "The target to run. Format: [project:]target"))
            .arg(arg!([args]... "Arguments to pass to the executable").trailing_var_arg(true)))
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

    match matches.subcommand() {
        None => {
            let beaver = Beaver::new(color, opt);
            let ctx = match beaver_ruby::execute(beaver, script_file) {
                Err(err) => panic!("{}", err),
                Ok(ctx) => ctx,
            };

            // ctx.context.create_build_file().unwrap();

            match ArgMatches::get_many::<String>(&matches, "targets") {
                Some(targets) => {
                    assert!(targets.len() > 0);
                    ctx.context.build_all(&targets.into_iter().map(|target_name| {
                        ctx.context.parse_target_ref(target_name).unwrap()
                    }).collect::<Vec<TargetRef>>()).unwrap();
                },
                None => {
                    ctx.context.build_current_project().unwrap();
                }
            }
        },
        Some(("list", _)) => {
            let beaver = Beaver::new(color, opt);
            let rb_context = match beaver_ruby::execute(beaver, script_file) {
                Err(err) => panic!("{}", err),
                Ok(ctx) => ctx,
            };
            println!("{}", rb_context.context);
        },
        Some(("clean", _)) => {
            unimplemented!("clean")
        },
        Some(("run", matches)) => {
            let beaver = Beaver::new(color, opt);
            let ctx = match beaver_ruby::execute(beaver, script_file) {
                Err(err) => panic!("{}", err),
                Ok(ctx) => ctx,
            };

            let target_name: Option<&String> = matches.get_one("target");
            let args = ArgMatches::get_many::<String>(&matches, "args");
            match target_name {
                Some(target_name) => {
                    let target = ctx.context.parse_target_ref(target_name).unwrap();
                    if let Some(args) = args {
                        ctx.context.run(target, args).unwrap()
                    } else {
                        ctx.context.run(target, [OsString::new();0].iter()).unwrap()
                    }
                },
                None => if let Some(args) = args {
                    ctx.context.run_default(args).unwrap()
                } else {
                    ctx.context.run_default([OsString::new();0].iter()).unwrap()
                }
            }
        }
        Some((subcommand_name, _)) => {
            unreachable!("Invalid subcommand {subcommand_name}")
        }
    }

}
