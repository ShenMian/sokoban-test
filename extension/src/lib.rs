use godot::prelude::*;

mod grid_map;
mod utils;

struct Extension;

#[gdextension]
unsafe impl ExtensionLibrary for Extension {}
