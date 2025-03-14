use std::path::{self, Path, PathBuf};
use enum_dispatch::enum_dispatch;
use target_lexicon::Triple;

use crate::target::targets;
use crate::target::{traits::Target, ArtifactType, LibraryArtifactType};

#[enum_dispatch]
pub trait Library: Target {
    fn artifact_output_dir(&self, project_build_dir: &Path, triple: &Triple) -> PathBuf;

    /// Writes C-style linker flags to `out`. If a static library or object file should be linked, the file is returned
    fn link_against_library(&self, project_build_dir: &Path, artifact: LibraryArtifactType, target_triple: &Triple, out: &mut Vec<String>, additional_files: &mut Vec<PathBuf>) -> crate::Result<()> {
        use LibraryArtifactType::*;

        if let Some(linker_flags) = self.additional_linker_flags() {
            out.extend(linker_flags.iter().cloned());
        }

        match artifact {
            Dynlib => {
                // TODO: do we need path::canonicalize?
                let outdir = path::absolute(self.artifact_output_dir(project_build_dir, target_triple))?;
                out.push(format!("-L{}", outdir.display()));
                out.push(format!("-l{}", self.name()));
            },
            Staticlib => {
                additional_files.push(path::absolute(self.artifact_file(project_build_dir, ArtifactType::Library(artifact), target_triple)?)?);
            }
            Framework => {
                let outdir = path::absolute(self.artifact_output_dir(project_build_dir, target_triple))?;
                out.push(format!("-F{}", outdir.display()));
                out.push("-framework".to_string());
                out.push(self.name().to_string());
            },
            XCFramework => todo!("XCFramework is unimplemented"),
            PkgConfig => panic!("Can't link against pkgconfig (bug)"),
            // TODO: make this function generic for linking against a target language
            RustLib => panic!("TODO: can't be linked"),
            RustDynlib => panic!("TODO: can't be linked")
        }

        Ok(())
    }

    fn library_artifacts(&self) -> Vec<LibraryArtifactType>;

    fn additional_linker_flags(&self) -> Option<&Vec<String>>;

    fn public_cflags(&self, project_base_dir: &Path, project_build_dir: &Path, collect_into: &mut Vec<String>);

    fn default_library_artifact(&self) -> Option<LibraryArtifactType> {
        let artifacts = self.library_artifacts();

        let order = [LibraryArtifactType::Staticlib, LibraryArtifactType::Dynlib, LibraryArtifactType::RustLib, LibraryArtifactType::RustDynlib];
        for artifact in &order {
            if artifacts.contains(artifact) {
                return Some(*artifact);
            }
        }

        return None;
    }
}

#[enum_dispatch(Target)]
#[enum_dispatch(Library)]
#[derive(Debug)]
pub enum AnyLibrary {
    C(targets::c::Library),
    CMake(targets::cmake::Library),
    Cargo(targets::cargo::Library),
    SPM(targets::spm::Library),
}
