use std::path::Path;
use target_lexicon::Triple;

use crate::target::{traits::Target, ArtifactType, LibraryArtifactType};

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

    fn public_cflags(&self, project_base_dir: &Path) -> Vec<String>;
}
