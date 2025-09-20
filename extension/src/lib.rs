use godot::prelude::*;

mod level_map;
mod utils;

struct Extension;

#[gdextension]
unsafe impl ExtensionLibrary for Extension {}
