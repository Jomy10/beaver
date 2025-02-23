pub enum DefaultArgument<T> {
    Default,
    Some(T)
}

impl<T> DefaultArgument<T> {
    pub(crate) fn or_default(self, default: T) -> T {
        match self {
            Self::Default => default,
            Self::Some(v) => v
        }
    }
}
