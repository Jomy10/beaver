use std::borrow::Cow;
use std::collections::HashMap;
use std::path::{Path, PathBuf};
use std::sync::{Arc, RwLock};

use program_communicator::socket::SocketUnixExt;
use target_lexicon::Triple;
use url::Url;

use crate::backend::{rules, BackendBuilder, BackendBuilderScope, BuildStep};
use crate::target::{ArtifactType, Dependency, ExecutableArtifactType, Language, Version};
use crate::traits::{self, TargetType};
use crate::{tools, Beaver, BeaverError};

use super::BuildCommand;

#[derive(Debug)]
pub struct Executable {
    id: Option<usize>,
    proj_id: Option<usize>,

    name: String,
    version: Option<Version>,
    description: Option<String>,
    homepage: Option<Url>,
    license: Option<String>,

    language: Language,
    dependencies: Vec<Dependency>,

    artifacts: HashMap<ExecutableArtifactType, PathBuf>,
    build_cmd: BuildCommand,
}

impl Executable {
    pub fn new(
        name: String,
        version: Option<Version>,
        description: Option<String>,
        homepage: Option<Url>,
        license: Option<String>,
        language: Language,
        dependencies: Vec<Dependency>,
        artifacts: HashMap<ExecutableArtifactType, PathBuf>,
        build_cmd: BuildCommand,
    ) -> Self {
        Self {
            id: None,
            proj_id: None,
            name,
            version,
            description,
            homepage,
            license,
            language,
            dependencies,
            artifacts,
            build_cmd,
        }
    }

    pub fn build(&self) -> crate::Result<()> {
        self.build_cmd.0()
    }
}

impl traits::Target for Executable {
    fn name(&self) -> &str {
        &self.name
    }

    fn description(&self) -> Option<&str> {
        self.description.as_deref()
    }

    fn homepage(&self) -> Option<&Url> {
        self.homepage.as_ref()
    }

    fn version(&self) -> Option<&Version> {
        self.version.as_ref()
    }

    fn license(&self) -> Option<&str> {
        self.license.as_deref()
    }

    fn language(&self) -> Language {
        self.language
    }

    fn id(&self) -> Option<usize> {
        self.id
    }

    fn set_id(&mut self, new_id: usize) {
        self.id = Some(new_id)
    }

    fn project_id(&self) -> Option<usize> {
        self.proj_id
    }

    fn set_project_id(&mut self, new_id: usize) {
        self.proj_id = Some(new_id)
    }

    fn artifacts(&self) -> Vec<ArtifactType> {
        self.artifacts
            .iter()
            .map(|(art, _)| ArtifactType::Executable(*art))
            .collect()
    }

    fn dependencies(&self) -> crate::Result<Cow<'_, [Dependency]>> {
        Ok(Cow::Borrowed(&[]))
    }

    fn r#type(&self) -> TargetType {
        TargetType::Executable
    }

    fn artifact_file(
        &self,
        _project_build_dir: &Path,
        artifact: ArtifactType,
        _triple: &Triple,
    ) -> crate::Result<PathBuf> {
        match self.artifacts.get(&artifact.as_executable().unwrap()) {
            Some(art_path) => {
                return Ok(art_path.clone());
            }
            None => {
                return Err(BeaverError::NoArtifact(artifact, self.name.clone()));
            }
        }
    }

    fn register<Builder: BackendBuilder<'static>>(
        &self,
        project_name: &str,
        _project_base_dir: &Path,
        _project_build_dir: &Path,
        _: &Triple,
        builder: Arc<RwLock<Builder>>,
        scope: &mut Builder::Scope,
        context: &Arc<Beaver>,
    ) -> crate::Result<String> {
        context.enable_communication()?;

        let mut guard = builder.write()
            .map_err(|err| BeaverError::BackendLockError(err.to_string()))?;
        guard.add_rule_if_not_exists(&rules::CUSTOM);
        drop(guard);

        let target_cmd_name = format!("{}$:{}", project_name, &self.name);
        let target_name = format!("{}:{}", project_name, &self.name);

        let mut deps = Vec::new();
        for dep in &self.dependencies {
            let Some(name) = dep.ninja_name(context)? else { continue; };
            deps.push(name);
        }
        let deps = deps.iter().map(|str| str.as_str()).collect::<Vec<&str>>();

        #[cfg(unix)] {
            let response_file = std::env::temp_dir().join("beaver_pipe_".to_string() + &uuid::Uuid::new_v4().to_string());
            let response_file = response_file.to_str().unwrap();

            let mut cmd = format!("{} {} && ", tools::mkfifo.to_str().unwrap(), response_file);
            context.comm_socket.0
                .get().expect("communication not initialized")
                .sh_write_str_netcat(&tools::netcat, &format!("build {}:{} {}", self.project_id().unwrap(), self.id().unwrap(), response_file), &mut cmd)
                .map_err(|err| BeaverError::AnyError(err.to_string()))?;
            cmd += &format!(" && {} $$({} \"{}\") -eq 0", tools::test.to_str().unwrap(), tools::cat.to_str().unwrap(), response_file);

            scope.add_step(&BuildStep::Cmd {
                rule: &rules::CUSTOM,
                name: &target_cmd_name,
                dependencies: deps.as_slice(),
                options: &[
                    ("name", &target_name),
                    ("cmd", &cmd)
                ]
            })?;
        }
        #[cfg(not(unix))] {
            panic!("custom targets not supported on this platform");
        }

        for (_, artifact_path) in &self.artifacts {
            let Some(path_str) = artifact_path.to_str() else {
                return Err(BeaverError::NonUTF8OsStr(artifact_path.as_os_str().to_os_string()));
            };

            scope.add_step(&BuildStep::Phony {
                name: path_str,
                args: &[&target_cmd_name],
                dependencies: &[],
            })?;
        }

        Ok(target_cmd_name)
    }

    fn debug_attributes(&self) -> Vec<(&'static str, String)> {
        vec![]
    }
}

impl traits::Executable for Executable {
    fn executable_artifacts(&self) -> Vec<ExecutableArtifactType> {
        self.artifacts.iter().map(|(k, _)| *k).collect()
    }
}
