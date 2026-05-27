use godot::prelude::*;
use soukoban::prelude::*;

pub trait ToGodot {
    type Out;
    fn to_gd(&self) -> Self::Out;
}

impl ToGodot for Point {
    type Out = Vector2i;
    fn to_gd(&self) -> Self::Out {
        Vector2i::new(self.x, self.y)
    }
}

pub trait ToSoukoban {
    type Out;
    fn to_point(&self) -> Self::Out;
}

impl ToSoukoban for Vector2i {
    type Out = Point;
    fn to_point(&self) -> Self::Out {
        Point::new(self.x, self.y)
    }
}
