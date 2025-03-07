#[derive(Debug)]
pub struct Flags {
    pub(crate) public: Vec<String>,
    pub(crate) private: Vec<String>,
}

impl Flags {
    pub fn new(public: Vec<String>, private: Vec<String>) -> Flags {
        Flags { public, private }
    }
}
