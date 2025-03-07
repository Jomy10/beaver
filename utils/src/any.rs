use std::any::Any;

pub trait AsAny {
    fn as_any(&self) -> &dyn Any;
    fn into_any(self) -> Box<dyn Any>;
}

impl<T: 'static> AsAny for T {
    fn as_any(&self) -> &dyn Any {
        self
    }

    fn into_any(self) -> Box<dyn Any> {
        Box::new(self)
    }
}
