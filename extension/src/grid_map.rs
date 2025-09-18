use godot::classes::{GridMap, IGridMap};
use godot::prelude::*;

#[derive(GodotClass)]
#[class(base=GridMap)]
struct LevelMap {
    base: Base<GridMap>,
}

#[godot_api]
impl IGridMap for LevelMap {
    fn init(base: Base<GridMap>) -> Self {
        godot_print!("Hello, world!");

        Self { base }
    }
}
