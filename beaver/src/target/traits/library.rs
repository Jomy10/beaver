use std::path::{self, Path};
use enum_dispatch::enum_dispatch;
use target_lexicon::Triple;

use crate::target::{traits::Target, ArtifactType, LibraryArtifactType};

#[enum_dispatch]
pub trait Library: Target {
    fn link_against_library(&self, project_build_dir: &Path, artifact: LibraryArtifactType, target_triple: &Triple) -> crate::Result<Vec<String>> {
        use LibraryArtifactType::*;
        match artifact {
            Dynlib => {
                // TODO: do we need path::canonicalize?
                let outdir = path::absolute(self.artifact_output_dir(project_build_dir, target_triple))?;
                Ok(vec![format!("-L{}", outdir.display()), format!("-l{}", self.name())])
            },
            Staticlib => Ok(vec![path::absolute(self.artifact_file(project_build_dir, ArtifactType::Library(artifact), target_triple)?)?.to_str().unwrap().to_string()]),
            Framework => {
                let outdir = path::absolute(self.artifact_output_dir(project_build_dir, target_triple))?;
                Ok(vec![format!("-F{}", outdir.display()), "-framework".to_string(), self.name().to_string()])
            },
            XCFramework => todo!("XCFramework is unimplemented"),
            PkgConfig => panic!("Can't link against pkgconfig (bug)")
        }
    }

    fn library_artifacts(&self) -> &[LibraryArtifactType];

    fn additional_linker_flags(&self) -> Option<&Vec<String>>;

    fn public_cflags(&self, project_base_dir: &Path) -> Vec<String>;

    fn default_library_artifact(&self) -> Option<LibraryArtifactType> {
        let artifacts = self.library_artifacts();

        if artifacts.contains(&LibraryArtifactType::Staticlib) {
            return Some(LibraryArtifactType::Staticlib);
        } else if artifacts.contains(&LibraryArtifactType::Dynlib) {
            return Some(LibraryArtifactType::Dynlib)
        } else {
            return None;
        }
    }
}

use crate::target::c::Library as CLibrary;

#[enum_dispatch(Target)]
#[enum_dispatch(Library)]
#[derive(Debug)]
pub enum AnyLibrary {
    CLibrary,
}
