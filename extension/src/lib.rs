use godot::prelude::*;

mod convert;
mod old_database;
mod direction;
mod level_map;
mod database;
mod orm;
mod strategy;

struct Extension;

#[gdextension]
unsafe impl ExtensionLibrary for Extension {}
