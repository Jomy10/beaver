use std::collections::HashMap;
use std::path::{Path, PathBuf};
use std::sync::{Arc, RwLock};

use log::trace;
use program_communicator::socket::SocketUnixExt;
use target_lexicon::Triple;
use url::Url;

use crate::{tools, Beaver, BeaverError};
use crate::backend::{rules, BackendBuilder, BackendBuilderScope, BuildStep};
use crate::target::{ArtifactType, Dependency, Language, LibraryArtifactType, Version};
use crate::traits::{self, TargetType};

use super::BuildCommand;

#[derive(Debug)]
pub struct Library {
    id: Option<usize>,
    proj_id: Option<usize>,

    name: String,
    version: Option<Version>,
    description: Option<String>,
    homepage: Option<Url>,
    license: Option<String>,

    language: Language,
    dependencies: Vec<Dependency>,

    linker_flags: Vec<String>,
    public_cflags: Vec<String>,

    artifacts: HashMap<LibraryArtifactType, PathBuf>,
    build_cmd: BuildCommand,
}

impl Library {
    pub fn new(
        name: String,
        version: Option<Version>,
        description: Option<String>,
        homepage: Option<Url>,
        license: Option<String>,
        language: Language,
        dependencies: Vec<Dependency>,
        artifacts: HashMap<LibraryArtifactType, PathBuf>,
        linker_flags: Vec<String>,
        public_cflags: Vec<String>,
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
            linker_flags,
            public_cflags,
            build_cmd,
        }
    }

    pub fn build(&self) -> crate::Result<()> {
        trace!("Building {:?}", self);
        self.build_cmd.0()
    }
}

impl traits::Target for Library {
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
            .map(|(art, _)| ArtifactType::Library(*art))
            .collect()
    }

    fn dependencies(&self) -> &[Dependency] {
        &self.dependencies
    }

    fn r#type(&self) -> TargetType {
        TargetType::Library
    }

    fn artifact_file(
        &self,
        _project_build_dir: &Path,
        artifact: ArtifactType,
        _triple: &Triple,
    ) -> crate::Result<PathBuf> {
        match self.artifacts.get(&artifact.as_library().unwrap()) {
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

        scope.add_comment(&target_cmd_name)?;

        #[cfg(unix)] {
            // TODO: cleanup this file when beaver exits
            let response_file = std::env::temp_dir().join("beaver_pipe_".to_string() + &uuid::Uuid::new_v4().to_string());
            if response_file.exists() {
                panic!("uuid clash");
            }
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
                    // ("bytes", &format!("'\\x01\\x{:0width$}\\x{:0width$}'", self.project_id().unwrap(), self.id().unwrap(), width = 2)),
                    // ("file", &context.communication_file_str()?.expect("Communication not initialized"))
                ]
            })?;
        }
        #[cfg(not(unix))] {
            panic!("custom targets not supported on this platform");
        }

        for (artifact, artifact_path) in &self.artifacts {
            let path = std::path::absolute(artifact_path)?;
            let Some(path_str) = path.to_str() else {
                return Err(BeaverError::NonUTF8OsStr(artifact_path.as_os_str().to_os_string()));
            };

            scope.add_step(&BuildStep::Phony {
                name: path_str,
                args: &[&target_cmd_name],
                dependencies: &[],
            })?;

            scope.add_step(&BuildStep::Phony {
                name: &format!("{}$:{}", &target_cmd_name, artifact),
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

impl traits::Library for Library {
    fn artifact_output_dir(&self, _project_build_dir: &Path, _triple: &Triple) -> PathBuf {
        panic!("No fixed artifact output dir")
    }

    fn library_artifacts(&self) -> Vec<LibraryArtifactType> {
        self.artifacts.iter().map(|(art, _)| *art).collect()
    }

    fn additional_linker_flags(&self) -> Option<&Vec<String>> {
        Some(&self.linker_flags)
    }

    #[doc = " - Collects the public C flags of this target into `collect_into`."]
    #[doc = " - Collects additional files to which the dependant should depend on into `additional_file_dependencies`."]
    #[doc = "   This could be for example generated files that are generated when this target is built."]
    fn public_cflags(&self, _project_base_dir: &Path, _project_build_dir: &Path, collect_into: &mut Vec<String>, _additional_file_dependencies: &mut Vec<PathBuf>) {
        collect_into.extend(self.public_cflags.iter().map(|str| str.clone()))
    }
}
