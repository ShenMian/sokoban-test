use godot::prelude::*;

mod convert;
mod database;
mod direction;
mod level_map;
mod strategy;

struct Extension;

#[gdextension]
unsafe impl ExtensionLibrary for Extension {}
