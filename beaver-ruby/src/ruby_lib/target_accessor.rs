use std::path::PathBuf;

use beaver::target::TargetRef;
use beaver::traits::Project;
use magnus::Module;

use crate::{BeaverRubyError, CTX};

#[magnus::wrap(class = "TargetAccessor")]
pub struct TargetAccessor {
    pub projid: usize,
    pub id: usize,
}

impl TargetAccessor {
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
}

pub fn register(ruby: &magnus::Ruby) -> crate::Result<()> {
    let class = ruby.define_class("TargetAccessor", ruby.class_object())?;
    class.define_method("run", magnus::method!(TargetAccessor::run, 1))?;
    class.define_method("build", magnus::method!(TargetAccessor::build, 0))?;
    class.define_method("set_pkgconfig", magnus::method!(TargetAccessor::set_pkgconfig, 1))?;

    return Ok(());
}
