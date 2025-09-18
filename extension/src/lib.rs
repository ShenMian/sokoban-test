use godot::prelude::*;

mod grid_map;

struct Extension;

#[gdextension]
unsafe impl ExtensionLibrary for Extension {}
