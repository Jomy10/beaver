use utils::moduse;

moduse!(library);
moduse!(executable);

pub struct BuildCommand(pub Box<dyn Fn() -> crate::Result<()> + Send + Sync>);

impl std::fmt::Debug for BuildCommand {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str("BuildCommand")
    }
}
