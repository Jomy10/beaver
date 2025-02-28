use std::path::PathBuf;

use beaver::project::beaver::Project as BeaverProject;
use beaver::traits::{AnyProject, Project};
use rutie::{class, methods, Class, Fixnum, NilClass, Object, RString, Symbol};
use log::trace;

use crate::{get_context, raise};

use super::target::TargetAccessor;

class!(ProjectAccessor);

methods!(
    ProjectAccessor,
    rtself,

    // TODO
    fn target(name: RString) -> TargetAccessor {
        let rerr = Class::from_existing("RuntimeError");

        let name = match name {
            Err(err) => raise!(err),
            Ok(val) => val,
        };

        let project_id = rtself.instance_variable_get("@id");
        let project_id = project_id.try_convert_to::<Fixnum>().unwrap();
        let project_id = project_id.to_i64() as usize;

        let context = get_context();
        let projects = match context.context.projects() {
            Err(err) => raise!(rerr, &err.to_string()),
            Ok(val) => val,
        };
        let project = &projects[project_id];

        let name = name.to_str();
        let Some(target_id) = (match project.find_target(name) {
            Err(err) => raise!(rerr, &err.to_string()),
            Ok(val) => val,
        }) else {
            raise!(rerr, &format!("Target {} not found in project {}", name, project.name()));
        };

        let mut target_accessor = Class::from_existing("TargetAccessor").allocate();
        target_accessor.instance_variable_set("@id", Fixnum::new(target_id as i64));

        return unsafe { target_accessor.to() };
    }
);

methods!(
    crate::GlobalModule,
    rtself,

    // TODO replace unwraps with raise
    fn def_project(args: rutie::Hash) -> ProjectAccessor {
        let args = match args {
            Err(err) => {
                trace!("{:?}", err);
                raise!(Class::from_existing("ArgumentError"), "`Project` requires at least a `name` argument")
            },
            Ok(args) => args
        };
        let context = crate::get_context();

        let base_dir = args.at(&Symbol::new("base_dir"));
        let base_dir = if base_dir.is_nil() { std::env::current_dir().unwrap() } else { PathBuf::from(base_dir.try_convert_to::<RString>().unwrap().to_string()) };
        let build_dir = match context.context.get_build_dir() {
            Ok(val) => val,
            Err(err) => raise!(Class::from_existing("RuntimeError"), &format!("{}", err))
        };
        let build_dir = build_dir.as_path();

        let project: AnyProject = BeaverProject::new(
            args.at(&Symbol::new("name")).try_convert_to::<RString>().unwrap().to_string(),
            base_dir,
            build_dir
        ).unwrap().into();
        let project_id = context.context.add_project(project).unwrap();

        let mut project_accessor = Class::from_existing("ProjectAccessor").allocate();
        project_accessor.instance_variable_set("@id", Fixnum::new(project_id as i64));

        return unsafe { project_accessor.to() };
    }

    fn test() -> NilClass {
        return NilClass::new();
    }
);

pub fn load(module: &mut rutie::Class) -> crate::Result<()> {
    let mut project_acc_klass = Class::new("ProjectAccessor", None);
    project_acc_klass.def("target", target);

    module.define_method("Project", def_project);

    return Ok(());
}
