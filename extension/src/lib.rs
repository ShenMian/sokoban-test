use godot::prelude::*;

mod level_map;
mod convert;

struct Extension;

#[gdextension]
unsafe impl ExtensionLibrary for Extension {}
