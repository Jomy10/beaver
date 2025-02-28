use std::path::Path;
use enum_dispatch::enum_dispatch;
use target_lexicon::Triple;

use crate::target::{traits::Target, ArtifactType, LibraryArtifactType};

#[enum_dispatch]
pub trait Library: Target {
    fn link_against_library(&self, project_build_dir: &Path, artifact: LibraryArtifactType, target_triple: &Triple) -> crate::Result<Vec<String>> {
        use LibraryArtifactType::*;
        match artifact {
            Dynlib => {
                let outdir = self.artifact_output_dir(project_build_dir, target_triple);
                Ok(vec![format!("-L{}", outdir.display()), format!("-l{}", self.name())])
            },
            Staticlib => Ok(vec![self.artifact_file(project_build_dir, ArtifactType::Library(artifact), target_triple)?.to_str().unwrap().to_string()]),
            Framework => {
                let outdir = self.artifact_output_dir(project_build_dir, target_triple);
                Ok(vec![format!("-F{}", outdir.display()), "-framework".to_string(), self.name().to_string()])
            },
            XCFramework => todo!("XCFramework is unimplemented"),
            PkgConfig => panic!("Can't link against pkgconfig (bug)")
        }
    }

    fn additional_linker_flags(&self) -> Option<&Vec<String>> {
        None
    }

    fn public_cflags(&self, project_base_dir: &Path) -> Vec<String>;

    fn default_library_artifact(&self) -> Option<LibraryArtifactType> {
        match self.default_artifact() {
            Some(ArtifactType::Library(lib)) => Some(lib),
            None => None,
            _ => unreachable!()
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
