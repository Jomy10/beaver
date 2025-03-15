use std::collections::HashSet;
use std::hash::Hash;

use crate::target::{Language, TArtifactType};
use crate::BeaverError;

pub(crate) fn check_language(
    expected: &[Language],
    got: &Language,
    target_type: &'static str
) -> crate::Result<()> {
    if !expected.contains(got) {
        Err(BeaverError::InvalidLanguage(*got, target_type))
    } else {
        Ok(())
    }
}

pub(crate) fn check_artifacts<ArtifactType: TArtifactType + Eq + Hash>(
    expected: &HashSet<ArtifactType>,
    got: &[ArtifactType],
    target_type: &'static str
) -> crate::Result<()> {
    if let Some(artifact) = got.iter().find(|artifact| !expected.contains(artifact)) {
        Err(BeaverError::InvalidArtifact((*artifact).into(), target_type))
    } else {
        Ok(())
    }
}
