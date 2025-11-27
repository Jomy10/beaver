use std::borrow::Cow;
use std::path::PathBuf;

use beaver::BeaverError;
use beaver::target::{Dependency, TargetRef};
use beaver::traits::{Project, Target};
use magnus::Module;

use crate::ext::MagnusConvertContextExt;
use crate::{BeaverRubyError, CTX};

/// Split on the value where `predicate` is false
fn split_iter<Iter: Iterator>(iter: Iter, predicate: impl Fn(&Iter::Item) -> bool) -> (std::vec::IntoIter<Iter::Item>, std::iter::Peekable<Iter>) {
    let mut first_part = Vec::new();
    let mut iter = iter.peekable();
    while let Some(n) = iter.peek() {
        if predicate(n) {
            first_part.push(iter.next().unwrap());
        } else {
            break;
        }
    }

    return (first_part.into_iter(), iter);
}

#[derive(Default)]
struct RunOptions {
    opt_mode: Option<beaver::OptimizationMode>,
}

impl RunOptions {
    fn update_from<'a>(&mut self, opts: &Vec<Cow<'a, str>>) -> Result<(), BeaverRubyError> {
        for opt in opts {
            match opt.as_ref() {
                "release" | "rel" => self.opt_mode = Some(beaver::OptimizationMode::Release),
                "debug" => self.opt_mode = Some(beaver::OptimizationMode::Debug),
                _ => return Err(BeaverRubyError::InvalidKey(opt.to_string()))
            }
        }

        return Ok(());
    }
}

#[magnus::wrap(class = "TargetAccessor")]
pub struct TargetAccessor {
    pub projid: usize,
    pub id: usize,
}

impl TargetAccessor {
    // TODO: make argument optional
    fn run(&self, args: magnus::RArray) -> Result<(), magnus::Error> {
        let context = &CTX.get().unwrap().context();

        let args = args.into_iter().map(|value| {
            match magnus::RString::from_value(value) {
                Some(val) => val.to_string(),
                None => Err(BeaverRubyError::IncompatibleType(value, "String").into()),
            }
        }).collect::<Result<Vec<String>, magnus::Error>>()?;
        context.run(TargetRef { project: self.projid, target: self.id }, args).map_err(|err| BeaverRubyError::from(err))?;

        Ok(())
    }

    /// Run the process on a separate thread
    fn run_thread(&self, args: magnus::RArray) -> Result<magnus::Thread, magnus::Error> {
        let context = &CTX.get().unwrap().context();

        let mut options = RunOptions::default();

        let (opts, args) = split_iter(
            args.into_iter(),
            |value|  magnus::Symbol::from_value(*value).is_some()
        );

        let opts = opts.map(|value| {
            let sym = magnus::Symbol::from_value(value).unwrap();
            return sym.name();
        }).collect::<Result<Vec<Cow<'_, str>>, magnus::Error>>()?;

        options.update_from(&opts)?;

        _ = options; // currently not handled

        let args = args.map(|value| {
            match magnus::RString::from_value(value) {
                Some(val) => val.to_string(),
                None => Err(BeaverRubyError::IncompatibleType(value, "String").into()),
            }
        }).collect::<Result<Vec<String>, magnus::Error>>()?;

        let projid = self.projid;
        let id = self.id;
        let context = context.clone();
        let handle = std::thread::spawn(move || {
            context.run(TargetRef { project: projid, target: id }, args)
                .map_err(|err| BeaverRubyError::from(err))
        });

        let ruby = magnus::Ruby::get().unwrap();

        let thr = ruby.thread_create_from_fn(|ruby| {
            loop {
                if handle.is_finished() {
                    let v = match handle.join() {
                        Ok(v) => v.map_err(|err| err.into()),
                        Err(err) => Err(BeaverRubyError::JoinError(err)),
                    }?;
                    return Ok(v);
                } else {
                    ruby.thread_sleep(std::time::Duration::from_millis(10))?;
                }
            }
        });

        thr.run()?;

        return Ok(thr);
    }

    fn build(&self) -> Result<(), magnus::Error> {
        let context = &CTX.get().unwrap().context.upgrade().expect("Beaver dropped before ruby");

        context.build(TargetRef { target: self.id, project: self.projid })
            .map_err(|err| BeaverRubyError::from(err).into())
    }

    /// Set the name of the pkgconfig file, or the path to the pkgconfig file for a Meson target
    fn set_pkgconfig(&self, name: String) -> Result<(), magnus::Error> {
        let context = &CTX.get().unwrap().context();

        context.with_project_and_target_mut::<(), BeaverRubyError>(&TargetRef { target: self.id, project: self.projid }, |project, target| {
            let path = if name.ends_with(".pc") {
                PathBuf::from(name)
            } else {
                project.build_dir().join("meson-uninstalled").join(name + "-uninstalled.pc")
            };

            match target {
                beaver::traits::AnyTarget::Library(any_library) => match any_library {
                    beaver::traits::AnyLibrary::Meson(library) => {
                        library.set_pkg_config_path(path).map_err(|err| err.into())
                    },
                    _ => Err(BeaverRubyError::SetPkgconfigOnNonMesonTarget)
                },
                beaver::traits::AnyTarget::Executable(_) => Err(BeaverRubyError::SetPkgconfigOnNonMesonTarget),
            }
        }).map_err(|err| err.into())
    }

    fn add_dependency(&self, dependency: magnus::Value) -> Result<(), magnus::Error> {
        let context = &CTX.get().unwrap().context();

        let dep = Dependency::try_from_value(dependency, context)?;

        context.with_project_and_target_mut::<(), BeaverError>(&TargetRef { target: self.id, project: self.projid }, |_, target| {
            target.add_dependency(dep)
        }).map_err(|err| BeaverRubyError::from(err).into())
    }
}

pub fn register(ruby: &magnus::Ruby) -> crate::Result<()> {
    let class = ruby.define_class("TargetAccessor", ruby.class_object())?;
    class.define_method("run", magnus::method!(TargetAccessor::run, 1))?;
    class.define_method("build", magnus::method!(TargetAccessor::build, 0))?;
    class.define_method("set_pkgconfig", magnus::method!(TargetAccessor::set_pkgconfig, 1))?;
    class.define_method("run_thread", magnus::method!(TargetAccessor::run_thread, 1))?;
    class.define_method("add_dependency", magnus::method!(TargetAccessor::add_dependency, 1))?;

    return Ok(());
}
