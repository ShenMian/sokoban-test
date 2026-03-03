use godot::prelude::*;
use nalgebra::Vector2;

pub trait ToGodot {
    type Out;
    fn to_gd(&self) -> Self::Out;
}

impl ToGodot for Vector2<i32> {
    type Out = Vector2i;
    fn to_gd(&self) -> Self::Out {
        Vector2i::new(self.x, self.y)
    }
}

pub trait ToNalgebra {
    type Out;
    fn to_na(&self) -> Self::Out;
}

impl ToNalgebra for Vector2i {
    type Out = Vector2<i32>;
    fn to_na(&self) -> Self::Out {
        Vector2::new(self.x, self.y)
    }
}
