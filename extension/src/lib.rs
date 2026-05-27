//! GDExtension bridge for the Sokoban.
//!
//! This crate exposes the core [soukoban] library to the Godot engine.

use godot::prelude::*;

/// Solver search algorithms.
mod algorithm;
/// Coordinate conversion traits between `soukoban` and Godot types.
mod convert;
/// SQLite-backed persistent storage for levels, collections, solutions, and snapshots.
mod database;
/// Godot-compatible direction enum with bidirectional `soukoban` conversion.
mod direction;
/// The core level map node: rendering, player/box movement, pathfinding, and solver integration.
mod level_map;
/// Solver optimality strategy enum with Godot export support.
mod strategy;

struct Extension;

#[gdextension]
unsafe impl ExtensionLibrary for Extension {}
