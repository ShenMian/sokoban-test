use godot::prelude::*;
use nalgebra::Vector2;

#[expect(dead_code)]
pub fn to_na_vec2(v: &Vector2i) -> Vector2<i32> {
    Vector2::new(v.x, v.y)
}

pub fn to_gd_vec2(v: &Vector2<i32>) -> Vector2i {
    Vector2i::new(v.x, v.y)
}
