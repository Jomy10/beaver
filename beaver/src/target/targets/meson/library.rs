use std::fs;
use std::path::{Path, PathBuf};
use std::sync::{Arc, RwLock};

use ouroboros::self_referencing;
use target_lexicon::Triple;
use url::Url;
use pkgconfig_parser::PkgConfig;
use log::*;

use crate::backend::{rules, BackendBuilder, BackendBuilderScope, BuildStep};
use crate::target::{ArtifactType, Dependency, Language, LibraryArtifactType, Version};
use crate::traits::{self, TargetType};
use crate::{Beaver, BeaverError};

#[self_referencing]
struct OwnedPkgConfig {
    file: PathBuf,
    data: String,
    #[borrows(data)]
    #[not_covariant]
    pkg_config: pkgconfig_parser::Result<PkgConfig<'this>>
}

impl std::fmt::Debug for OwnedPkgConfig {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        self.with_pkg_config(|pkg_config| {
            std::fmt::Debug::fmt(pkg_config, f)
        })
    }
}

#[derive(Debug)]
pub struct Library {
    project_id: Option<usize>,
    id: Option<usize>,

    meson_id: String,
    name: String,
    version: Version,
    language: Language,
    artifact_type: LibraryArtifactType,
    artifact: PathBuf,

    pkg_config: Option<OwnedPkgConfig>,
}

impl Library {
    pub fn new(
        meson_id: String,
        name: String,
        version: Version,
        language: Language,
        artifact_type: LibraryArtifactType,
        artifact: PathBuf,
        project_build_dir: &Path
    ) -> crate::Result<Self> {
        let pc_path = project_build_dir.join("meson-uninstalled").join(format!("{}-uninstalled.pc", name));
        let pc = if !pc_path.exists() {
            debug!("Meson library did not have pkg-config at {}", pc_path.display());
            None
        } else {
            let pc = fs::read_to_string(&pc_path)?;
            let pkg_config = OwnedPkgConfigBuilder {
                file: pc_path,
                data: pc,
                pkg_config_builder: |data| {
                    PkgConfig::parse(data)
                }
            }.build();
            Some(pkg_config)
        };
        Ok(Self {
            project_id: None,
            id: None,
            meson_id,
            name,
            version,
            language,
            artifact_type,
            artifact,
            pkg_config: pc
        })
    }
}

impl Library {
    pub fn meson_id(&self) -> &str {
        &self.meson_id
    }
}

impl traits::Target for Library {
    fn name(&self) ->  &str {
        &self.name
    }

    fn description(&self) -> Option<&str> {
        None
    }

    fn homepage(&self) -> Option<&Url> {
        None
    }

    fn version(&self) -> Option<&Version> {
        Some(&self.version)
    }

    fn license(&self) -> Option<&str> {
        None
    }

    fn language(&self) -> Language {
        self.language
    }

    fn id(&self) -> Option<usize> {
        self.id
    }

    fn set_id(&mut self, new_id: usize) {
        self.id = Some(new_id);
    }

    fn project_id(&self) -> Option<usize> {
        self.project_id
    }

    fn set_project_id(&mut self, new_id: usize) {
        self.project_id = Some(new_id);
    }

    fn artifacts(&self) -> Vec<ArtifactType> {
        vec![ArtifactType::Library(self.artifact_type)]
    }

    fn dependencies(&self) ->  &[Dependency] {
        &[]
    }

    fn r#type(&self) -> TargetType {
        TargetType::Library
    }

    fn artifact_file(&self, _project_build_dir: &Path, _artifact: ArtifactType, _triple: &Triple) -> crate::Result<PathBuf> {
        Ok(self.artifact.clone())
    }

    fn register<Builder: BackendBuilder<'static>>(
        &self,
        project_name: &str,
        _project_base_dir: &Path,
        project_build_dir: &Path,
        triple: &Triple,
        _builder: Arc<RwLock<Builder>>,
        scope: &mut Builder::Scope,
        _context: &Arc<Beaver>
    ) -> crate::Result<String> {
        #[cfg(debug_assertions)] {
            scope.add_comment(&format!("{}:{}", &self.name, self.artifact_type))?;
        }

        let Some(project_build_dir_str) = project_build_dir.as_os_str().to_str() else {
            return Err(BeaverError::NonUTF8OsStr(project_build_dir.as_os_str().to_os_string()));
        };

        let target_cmd_name = format!("{}$:{}", project_name, &self.name);

        scope.add_step(&BuildStep::Cmd {
            rule: &rules::MESON,
            name: &target_cmd_name,
            dependencies: &[],
            options: &[
                ("mesonBuildDir", project_build_dir_str),
                ("target", &self.name)
            ]
        })?;

        let target_cmd = format!("{}$:{}", &target_cmd_name, self.artifact_type);
        scope.add_step(&BuildStep::Phony {
            name: &target_cmd,
            args: &[&target_cmd_name],
            dependencies: &[]
        })?;

        let artifact_file = self.artifact_file(project_build_dir, ArtifactType::Library(self.artifact_type), triple)?;
        let artifact_file = crate::path::path_to_str(&artifact_file)?;
        scope.add_step(&BuildStep::Phony {
            name: artifact_file,
            args: &[&target_cmd_name],
            dependencies: &[],
        })?;

        Ok(target_cmd_name)
    }

    /// Debug attributes to print when using `--debug`
    fn debug_attributes(&self) -> Vec<(&'static str,String)> {
        vec![
            ("meson_id", self.meson_id.clone())
        ]
    }
}

impl traits::Library for Library {
    fn library_artifacts(&self) -> Vec<LibraryArtifactType> {
        vec![self.artifact_type]
    }

    fn public_cflags(&self, _project_base_dir: &Path, _project_build_dir: &Path, out: &mut Vec<String>, _: &mut Vec<PathBuf>) -> crate::Result<()> {
        let Some(pkg_config) = &self.pkg_config else {
            return Ok(());
        };

        pkg_config.with_pkg_config(|pkg_config| {
            pkg_config.as_ref().map(|pkg_config| {
                if let Some(libs) = pkg_config.cflags() {
                    if let Some(mut args) = shlex::split(&libs) {
                        out.append(&mut args);
                    }
                }
            })
        }).map_err(|err| BeaverError::PkgconfigParsingError(pkg_config.borrow_file().clone(), err.clone()))
    }

    fn additional_linker_flags(&self, project_build_dir: &Path, triple: &Triple, out: &mut Vec<String>) -> crate::Result<()> {
        if self.artifact_type == LibraryArtifactType::Dynlib {
            out.push(format!("-Wl,-rpath,{}", self.artifact_output_dir(project_build_dir, triple).display()));
        }

        let Some(pkg_config) = &self.pkg_config else {
            info!("Linking with Meson targets requires pkg-config to be configured. Target {} does not have pkg-config configured and might not be linked properly, you might need to manually link the target.", &self.name);
            return Ok(());
        };

        pkg_config.with_pkg_config(|pkg_config| {
            pkg_config.as_ref().map(|pkg_config| {
                if let Some(libs) = pkg_config.libs() {
                    if let Some(mut args) = shlex::split(&libs) {
                        out.append(&mut args);
                    }
                }
            })
        }).map_err(|err| BeaverError::PkgconfigParsingError(pkg_config.borrow_file().clone(), err.clone()))
    }

    fn artifact_output_dir(&self, _project_build_dir: &Path, _triple: &Triple) -> PathBuf {
        self.artifact.parent().unwrap().to_path_buf()
    }
}
