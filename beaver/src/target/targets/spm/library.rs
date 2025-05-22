use std::borrow::Cow;
use std::path::{Path, PathBuf};
use std::sync::{Arc, RwLock};

use target_lexicon::Triple;
use url::Url;

use crate::backend::BackendBuilder;
use crate::platform::{dynlib_extension_for_os, staticlib_extension_for_os};
use crate::target::{ArtifactType, Dependency, Language, LibraryArtifactType, Version};
use crate::traits::{self, TargetType};
use crate::Beaver;

#[derive(Debug)]
pub struct Library {
    project_id: Option<usize>,
    id: Option<usize>,

    name: String,
    artifact: LibraryArtifactType,

    cache_dir: Arc<PathBuf>,
}

impl Library {
    pub(crate) fn new(name: String, artifact: LibraryArtifactType, cache_dir: Arc<PathBuf>) -> Self {
        Library {
            project_id: None,
            id: None,
            name,
            artifact,
            cache_dir
        }
    }
}

impl traits::Target for Library {
    fn name(&self) -> &str {
        &self.name
    }

    fn description(&self) -> Option<&str> {
        None
    }

    fn homepage(&self) -> Option<&Url> {
        None
    }

    fn version(&self) -> Option<&Version> {
        None
    }

    fn license(&self) -> Option<&str> {
        None
    }

    fn language(&self) -> Language {
        Language::Swift
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
        vec![ArtifactType::Library(self.artifact)]
    }

    fn dependencies(&self) -> crate::Result<Cow<'_, [Dependency]>> {
        Ok(Cow::Borrowed(&[]))
    }

    fn r#type(&self) -> TargetType {
        TargetType::Library
    }

    fn artifact_file(
        &self,
        project_build_dir: &Path,
        artifact: ArtifactType,
        triple: &Triple,
    ) -> crate::Result<PathBuf> {
        let ext = match artifact.as_library().unwrap() {
            LibraryArtifactType::Dynlib => dynlib_extension_for_os(&triple.operating_system),
            LibraryArtifactType::Staticlib => staticlib_extension_for_os(&triple.operating_system),
            _ => unreachable!("invalid artifact type for target (bug)")
        }?;
        let artifact_name = format!("lib{}.{}", self.name(), ext);

        Ok(traits::Library::artifact_output_dir(self, project_build_dir, triple).join(artifact_name))
    }

    #[doc = " Returns the target name"]
    fn register<Builder: BackendBuilder<'static>>(
        &self,
        project_name: &str,
        project_base_dir: &Path,
        project_build_dir: &Path,
        triple: &Triple,
        _builder: Arc<RwLock<Builder>>,
        scope: &mut Builder::Scope,
        _context: &Arc<Beaver>,
    ) -> crate::Result<String> {
        let artifact_file = std::path::absolute(self.artifact_file(project_build_dir, ArtifactType::Library(self.artifact), triple)?)?;
        super::register_target(scope, project_name, &self.name, project_base_dir, &artifact_file, self.artifact, &self.cache_dir, Some(&self.swift_objc_header_path(project_build_dir)))
    }

    #[doc = " Debug attributes to print when using `--debug`"]
    fn debug_attributes(&self) -> Vec<(&'static str, String)> {
        vec![]
    }
}

impl traits::Library for Library {
    fn artifact_output_dir(&self, project_build_dir: &Path, _triple: &Triple) -> PathBuf {
        project_build_dir.to_path_buf()
    }

    fn library_artifacts(&self) -> Vec<LibraryArtifactType> {
        vec![self.artifact]
    }

    fn additional_linker_flags(&self, _: &Path, _: &Triple, _: &mut Vec<String>) -> crate::Result<()> {
        Ok(())
    }

    fn public_cflags(&self, _project_base_dir: &Path, project_build_dir: &Path, collect_into: &mut Vec<String>, additional_file_dependencies: &mut Vec<PathBuf>) -> crate::Result<()> {
        let include_path = self.swift_objc_header_search_path(project_build_dir);
        collect_into.push(format!("-I{}", include_path.display()));

        additional_file_dependencies.push(self.swift_objc_header_path(project_build_dir));

        Ok(())
    }
}

impl Library {
    /// include {product-name}-Swift.h path
    fn swift_objc_header_search_path(&self, project_build_dir: &Path) -> PathBuf {
        project_build_dir.join(format!("{}.build", self.name.replace("-", "_")))
    }

    fn swift_objc_header_path(&self, project_build_dir: &Path) -> PathBuf {
        self.swift_objc_header_search_path(project_build_dir)
            .join(format!("{}-Swift.h", self.name))
    }
}
