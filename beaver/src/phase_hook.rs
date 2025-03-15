use crate::BeaverError;

#[derive(Debug, PartialEq, Eq)]
pub enum Phase {
    Build,
    Run,
    Clean,
}

impl TryFrom<&str> for Phase {
    type Error = BeaverError;

    fn try_from(value: &str) -> Result<Self, Self::Error> {
        match value {
            "build" => Ok(Phase::Build),
            "run" => Ok(Phase::Run),
            "clean" => Ok(Phase::Clean),
            _ => Err(BeaverError::InvalidPhase(value.to_string()))
        }
    }
}

pub type PhaseHook = Box<dyn FnOnce() -> Result<(), Box<dyn std::error::Error>> + Send>;

pub(crate) struct PhaseHooks(pub Vec<PhaseHook>);

impl std::fmt::Debug for PhaseHooks {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_fmt(format_args!("PhaseHooks(hooks: {})", self.0.len()))
    }
}
