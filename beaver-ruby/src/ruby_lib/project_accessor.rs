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
        let context = &CTX.get().unwrap().context();
        let projects = context.projects().map_err(|err| BeaverRubyError::from(err))?;
        let project = projects.iter().find(|project| project.name() == name);
        let Some(project) = project else {
            return Err(BeaverRubyError::from(BeaverError::NoProjectNamed(name.to_string())).into());
        };

        return Ok(ProjectAccessor { id: project.id().unwrap() });
    }

    fn access_current() -> Result<ProjectAccessor, magnus::Error> {
        let context = &CTX.get().unwrap().context();
        let current_project = context.current_project_index()
            .ok_or_else(|| BeaverRubyError::from(BeaverError::NoProjects))?;
        return Ok(ProjectAccessor { id: current_project });
    }

    fn target(&self, name: String) -> Result<TargetAccessor, magnus::Error> {
        let context = &CTX.get().unwrap().context();
        let projects = context.projects().map_err(|err| BeaverRubyError::from(err))?;
        let target = projects[self.id].find_target(&name).map_err(|err| BeaverRubyError::from(err))?;
        let Some(target) = target else {
            return Err(BeaverRubyError::from(BeaverError::NoTargetNamed(name, projects[self.id].name().to_string())).into());
        };

        Ok(TargetAccessor { projid: self.id, id: target })
    }

    fn build_dir(&self) -> Result<magnus::RString, magnus::Error> {
        let context = &CTX.get().unwrap().context();
        let projects = context.projects().map_err(|err| BeaverRubyError::from(err))?;
        Ok(magnus::RString::new(projects[self.id].build_dir().as_os_str().to_str()
            .ok_or_else(|| BeaverRubyError::from(BeaverError::NonUTF8OsStr(projects[self.id].base_dir().as_os_str().to_os_string())))?
        ))
    }

    fn base_dir(&self) -> Result<magnus::RString, magnus::Error> {
        let context = &CTX.get().unwrap().context();
        let projects = context.projects().map_err(|err| BeaverRubyError::from(err))?;
        Ok(magnus::RString::new(projects[self.id].base_dir().as_os_str().to_str()
            .ok_or_else(|| BeaverRubyError::from(BeaverError::NonUTF8OsStr(projects[self.id].base_dir().as_os_str().to_os_string())))?
        ))
    }

    fn name(&self) -> Result<magnus::RString, magnus::Error> {
        let context = &CTX.get().unwrap().context();
        let projects = context.projects().map_err(|err| BeaverRubyError::from(err))?;
        Ok(magnus::RString::new(projects[self.id].name()))
    }
}

pub fn register(ruby: &magnus::Ruby) -> crate::Result<()> {
    let class = ruby.define_class("ProjectAccessor", ruby.class_object())?;
    class.define_method("target", magnus::method!(ProjectAccessor::target, 1))?;
    class.define_method("build_dir", magnus::method!(ProjectAccessor::build_dir, 0))?;
    class.define_method("base_dir", magnus::method!(ProjectAccessor::base_dir, 0))?;
    class.define_method("name", magnus::method!(ProjectAccessor::name, 0))?;

    ruby.define_global_function("project", magnus::function!(ProjectAccessor::access, 1));
    ruby.define_global_function("current_project", magnus::function!(ProjectAccessor::access_current, 0));

    Ok(())
}
