use std::path::{Path, PathBuf};
use std::sync::{Arc, RwLock};

use target_lexicon::Triple;

use crate::backend::{BackendBuilder, BackendBuilderScope, BuildStep, Rule};
use crate::target::parameters::{DefaultArgument, Files, Flags, Headers};
use crate::target::{Dependency, Language, TArtifactType, Version};
use crate::{traits, Beaver, BeaverError};

pub struct TargetDescriptor<ArtifactType> {
    pub name: String,
    pub description: Option<String>,
    pub homepage: Option<url::Url>,
    pub version: Option<Version>,
    pub license: Option<String>,
    pub language: Language,
    pub sources: Files,
    pub cflags: Flags,
    pub headers: Headers,
    pub linker_flags: Vec<String>,
    pub artifacts: DefaultArgument<Vec<ArtifactType>>,
    pub dependencies: Vec<Dependency>
}

pub trait CTarget: traits::Target {
    type TargetArtifactType: TArtifactType;

    fn user_cflags(&self) -> impl Iterator<Item = &String>;
    /// Both public and private headers
    fn all_headers<'a>(&'a self, project_base_dir: &'a Path) -> impl Iterator<Item = PathBuf> + 'a;

    fn target_artifacts(&self) -> &[Self::TargetArtifactType];

    // TODO: return iter?
    fn cflags<'a>(
        &self,
        project_base_dir: &Path,
        dependencies: impl Iterator<Item = &'a Dependency>,
        context: &Beaver
    ) -> crate::Result<Vec<String>> {
        let mut cflags: Vec<String> = Vec::from(&["-c".to_string()]);
        cflags.extend(self.user_cflags().map(|string| string.clone()));
        cflags.extend(self.all_headers(project_base_dir).map(|path| format!("-I{}", path.display())));

        for dependency in dependencies {
            let Some(mut flags) = dependency.public_cflags(context)? else {
                continue;
            };
            cflags.append(&mut flags);
        }

        cflags.extend(context.optimize_mode.cflags().iter().map(|str| str.to_string()));

        return Ok(cflags);
    }

    // TODO: return iter?
    fn linker_flags<'a>(
        &self,
        dependencies: impl Iterator<Item = &'a Dependency>,
        triple: &Triple,
        context: &Beaver
    ) -> crate::Result<Vec<String>>;

    fn register_impl<Builder: BackendBuilder<'static>>(&self,
        project_name: &str,
        project_base_dir: &Path,
        project_build_dir: &Path,
        target_triple: &Triple,
        builder: Arc<RwLock<Builder>>,
        rules: &[&'static Rule],
        context: &crate::Beaver
    ) -> crate::Result<()> {
        let mut guard = builder.write()
            .map_err(|err| BeaverError::BackendLockError(err.to_string()))?;
        for rule in rules {
            guard.add_rule_if_not_exists(rule);
        }

        let mut scope = guard.new_scope();
        drop(guard);

        let dependency_steps = self.dependencies().iter()
            .filter_map(|dep| {
                match dep.ninja_name(context) {
                    Err(err) => Some(Err(err)),
                    Ok(val) => match val {
                        Some(val) => Some(Ok(val)),
                        None => None
                    }
                }
            }).collect::<crate::Result<Vec<String>>>()?;
        let dependency_steps = dependency_steps.iter()
            .map(|str| str.as_str())
            .collect::<Vec<&str>>();

        let dependencies = self.unique_dependencies_set(context)?;
        let mut artifact_steps: Vec<String> = Vec::new();
        artifact_steps.reserve_exact(self.artifacts().len());
        let cflags = self.cflags(project_base_dir, dependencies.iter(), context)?;
        let cflags_str = utils::flags::concat_quoted(cflags.into_iter());
        let linker_flags = self.linker_flags(dependencies.iter(), target_triple, context)?;
        let linker_flags_str = utils::flags::concat_quoted(linker_flags.into_iter());

        for artifact in self.target_artifacts() {
            artifact_steps.push(self.register_artifact(
                artifact,
                project_name, project_base_dir, project_build_dir,
                &target_triple,
                &dependency_steps,
                &cflags_str,
                &linker_flags_str,
                &mut scope
            )?);
        }

        let target_step = format!("{}$:{}", project_name, self.name());
        scope.add_step(&BuildStep::Phony {
            name: &target_step,
            args: &artifact_steps.iter().map(|str| str.as_str()).collect::<Vec<&str>>(),
            dependencies: &[]
        })?;

        let mut builder_guard = builder.write()
            .map_err(|err| BeaverError::BackendLockError(err.to_string()))?;
        builder_guard.apply_scope(scope);

            return Ok(());
    }

    fn register_artifact<Scope: BackendBuilderScope>(
        &self,
        artifact: &Self::TargetArtifactType,
        project_name: &str,
        project_base_dir: &Path,
        project_build_dir: &Path,
        target_triple: &Triple,
        dependency_steps: &[&str],
        cflags: &str,
        linker_flags: &str,
        builder: &mut Scope
    ) -> crate::Result<String>;
}
