use std::collections::LinkedList;
use std::ffi::OsString;
use std::path::Path;

use beaver::target::TargetRef;
use beaver::{Beaver, BeaverError, OptimizationMode};
use clap::{arg, Arg, ArgAction, ArgMatches, Command, ValueHint};
use lazy_static::lazy_static;
use log::warn;

include!(concat!(env!("OUT_DIR"), "/rb_const_gen.rs"));

lazy_static! {
    static ref default_opt_mode: OsString = Into::<OsString>::into(OptimizationMode::default());
    static ref release_opt_mode: OsString = Into::<OsString>::into(OptimizationMode::Release);
}

struct MainError {
    inner: Box<dyn std::error::Error + 'static>
}

impl<E: std::error::Error + 'static> From<E> for MainError {
    fn from(value: E) -> Self {
        Self { inner: Box::new(value) }
    }
}

impl std::fmt::Debug for MainError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str(&console::style(format!("{}", self.inner.as_ref())).red().to_string())
    }
}

fn main() -> Result<(), MainError> {
    let build_args = [
        arg!(-o --opt [OPT] "Optimization mode")
            .default_value(default_opt_mode.as_os_str())
            .default_missing_value(release_opt_mode.as_os_str())
            .value_hint(ValueHint::Other)
            .long_help("Optimization mode
            When the argument is provided, but without a value, then the optimization mode is set to release")
            .value_parser(["debug", "release"])
            .ignore_case(true)
            .help_heading("Build options"),
    ];

    let matches = Command::new("beaver")
        .author("Jonas Everaert")
        .version(VERSION)
        .long_version(LONG_VERSION) // TODO: ninja version
        .propagate_version(true)
        .about("Reliable, powerful build system")

        // Global arguments
        .arg(Arg::new("script-file")
            .short('f')
            .long("script-file")
            .value_name("FILE")
            .value_hint(ValueHint::FilePath)
            .help("The path to the script file")
            .global(true))
        .arg(arg!(--color "Enable color output (default: automatic)")
            .global(true))
        .arg(Arg::new("no-color")
            .long("no-color")
            .action(ArgAction::SetTrue)
            .conflicts_with("color")
            .hide(true)
            .global(true))
        .arg(arg!(--debug "Print debug information")
            .hide_short_help(true)
            .global(true))
        .arg(Arg::new("verbosity")
            .short('v')
            .long("verbose")
            .action(ArgAction::Count)
            .help("Sets the level of verbosity")
            .global(true))

        // Build arguments
        .args(build_args.iter())
        .arg(arg!([targets]... "Target(s) to build")
            .long_help("Target(s) to build\nWhen no targets are passed, all targets in the current project are built."))

        // Var args passed to script
        .arg(arg!([args]... "Arguments passed to the build script")
            .required(false)
            .last(true)
            .global(true))

        // Subcommands
        .subcommand(Command::new("run")
            .about("Build and run an executable target")
            .arg(arg!([target] "The target to run. Format: [project:]target"))
            .arg(arg!([args]... "Arguments passed to the executable to run"))
            .args(build_args.iter()))

        .subcommand(Command::new("clean")
            .about("Clean the project")
            .long_about("Clean the project. By default this command will clean all projects, unless a specific project is passed as an argument to this command")
            .arg(arg!([projects]... "The projects to clean")
                .long_help("The projects to clean. When not passed, will clean all projects")))

        .subcommand(Command::new("list")
            .about("List projects and targets from the script file")
            .long_about("List projects and targets from the script file. This will execute the script file, but not any pre-phase hooks"))

        .get_matches();

    run_cli(&matches)
}

fn run_cli(matches: &ArgMatches) -> Result<(), MainError> {
    let debug = matches.get_one::<bool>("debug").unwrap();

    let mut clog = colog::default_builder();
    #[cfg(debug_assertions)] { clog.filter(None, log::LevelFilter::Trace); }
    #[cfg(not(debug_assertions))] { clog.filter(None, log::LevelFilter::Warn); }

    let verbosity = if *debug { 3 } else { matches.get_count("verbosity") };
    // dbg!(&matches);
    #[cfg(not(debug_assertions))] {
        match verbosity {
            0 => {},
            1 => { clog.filter(None, log::LevelFilter::Info); },
            2 => { clog.filter(None, log::LevelFilter::Debug); },
            3.. => { clog.filter(None, log::LevelFilter::Trace); },
        }
    }

    clog.init();

    // Look for any of these files, in this order
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

    let flag_color = matches.get_flag("color");
    let flag_no_color = matches.get_flag("no-color");
    if flag_color == true && flag_no_color == true { warn!("Both --color and --no-color are specified. --color will get priority") };
    let color = if flag_color == false && flag_no_color == false { None } else { Some(flag_color || !flag_no_color) };
    let color = if let Some(color) = color {
        console::set_colors_enabled(color);
        console::set_colors_enabled_stderr(color);
        color
    } else {
        console::colors_enabled()
    };

    let script_args = matches.get_many::<String>("args");
    let script_args = if let Some(args) = script_args {
        LinkedList::from_iter(args.into_iter().map(|str| str.clone()))
    } else {
        LinkedList::new()
    };

    // build args
    let opt = match matches.subcommand() {
        None => OptimizationMode::try_from(matches.get_one::<String>("opt").unwrap().as_str())?,
        Some(("run", matches)) => OptimizationMode::try_from(matches.get_one::<String>("opt").unwrap().as_str())?,
        _ => OptimizationMode::default()
    };

    // Execute script
    let beaver = Box::new(Beaver::new(Some(color), opt, verbosity != 0)?);
    let ctx = unsafe { beaver_ruby::execute_script(script_file, script_args, beaver)? };

    if *debug {
        let mut str = String::new();
        ctx.context.fmt_debug(&mut str)?;
        eprintln!("{}", str);
    }

    let beaver = &ctx.context;

    // Execute subcommand
    match matches.subcommand() {
        None => { // build / cmd
            match matches.get_many::<String>("targets") {
                Some(targets) => {
                    assert!(targets.len() > 0);
                    let mut targets = targets.peekable();

                    if beaver.has_command(targets.peek().unwrap())? {
                        for command in targets {
                            beaver.run_command(command)?;
                        }
                    } else {
                        beaver.build_all(&targets.into_iter().map(|target_name| {
                            beaver.parse_target_ref(target_name)
                        }).collect::<Result<Vec<TargetRef>, BeaverError>>()?)?;
                    }
                },
                None => {
                    if beaver.projects()?.len() > 0 {
                        beaver.build_current_project()?;
                    }
                }
            }
        },
        Some(("run", matches)) => {
            let target_name: Option<&String> = matches.get_one("target");
            let args = matches.get_many::<String>("args");
            match target_name {
                Some(target_name) => {
                    let target = beaver.parse_target_ref(target_name)?;
                    if let Some(args) = args {
                        beaver.run(target, args)?;
                    } else {
                        beaver.run(target, [OsString::new();0].iter())?;
                    }
                },
                None => {
                    if let Some(args) = args {
                        beaver.run_default(args)?
                    } else {
                        beaver.run_default([OsString::new();0].iter())?
                    }
                }
            }
        },
        Some(("list", _)) => {
            print!("{}", beaver)
        },
        Some(("clean", matches)) => {
            if let Some(_projects) = matches.get_many::<String>("projects") {
                unimplemented!("Explicit project cleaning")
            } else {
                beaver.clean()?
            }
        },
        Some((subcommand_name, _)) => {
            unreachable!("Invalid subcommand {subcommand_name}")
        }
    }

    if ctx.has_args() {
        warn!("Unused arguments: {:?}", *ctx.args());
    }

    Ok(())
}
