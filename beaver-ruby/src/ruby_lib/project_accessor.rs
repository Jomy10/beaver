use beaver::traits::Project;
use beaver::BeaverError;

use magnus::Module;

use crate::{BeaverRubyError, CTX};

use super::target_accessor::TargetAccessor;

#[derive(Debug)]
#[magnus::wrap(class = "ProjectAccessor")]
pub struct ProjectAccessor {
    pub id: usize,
}

impl ProjectAccessor {
    fn access(name: String) -> Result<ProjectAccessor, magnus::Error> {
        let context = &CTX.get().unwrap().context;
        let projects = context.projects().map_err(|err| BeaverRubyError::from(err))?;
        let project = projects.iter().find(|project| project.name() == name);
        let Some(project) = project else {
            return Err(BeaverRubyError::from(BeaverError::NoProjectNamed(name.to_string())).into());
        };

        return Ok(ProjectAccessor { id: project.id().unwrap() });
    }

    fn target(&self, name: String) -> Result<TargetAccessor, magnus::Error> {
        let context = &CTX.get().unwrap().context;
        let projects = context.projects().map_err(|err| BeaverRubyError::from(err))?;
        let target = projects[self.id].find_target(&name).map_err(|err| BeaverRubyError::from(err))?;
        let Some(target) = target else {
            return Err(BeaverRubyError::from(BeaverError::NoTargetNamed(projects[self.id].name().to_string(), name)).into());
        };

        Ok(TargetAccessor { projid: self.id, id: target })
    }
}

pub fn register(ruby: &magnus::Ruby) -> crate::Result<()> {
    let class = ruby.define_class("ProjectAccessor", ruby.class_object())?;
    class.define_method("target", magnus::method!(ProjectAccessor::target, 1))?;

    ruby.define_global_function("project", magnus::function!(ProjectAccessor::access, 1));

    Ok(())
}
