use std::collections::HashMap;
use std::str::FromStr;

use godot::classes::{GridMap, IGridMap};
use godot::prelude::*;
use nalgebra::Vector2;
use soukoban::{Actions, Map, Tiles};

use crate::utils::*;

#[derive(GodotClass)]
#[class(base=GridMap)]
struct LevelMap {
    map: Map,
    base: Base<GridMap>,
}

#[godot_api]
impl IGridMap for LevelMap {
    fn init(base: Base<GridMap>) -> Self {
        let map = Map::from_actions(Actions::from_str("R").unwrap()).unwrap();
        Self { map, base }
    }

    fn ready(&mut self) {
        godot_print!("LevelMap is ready!");
    }
}

#[godot_api]
impl LevelMap {
    #[func]
    fn load_from_string(&mut self, lurd: GString) {
        let Ok(actions) = Actions::from_str(&lurd.to_string()) else {
            godot_print!("Failed to parse actions from string: {}", lurd);
            return;
        };
        let Ok(map) = Map::from_actions(actions) else {
            godot_print!("Failed to create map from actions: {}", lurd);
            return;
        };
        self.map = map;
        self.build();
    }

    #[func]
    fn dimensions(&self) -> Vector2i {
        to_gd_vec2(self.map.dimensions())
    }

    #[func]
    fn player_position(&self) -> Vector2i {
        to_gd_vec2(self.map.player_position())
    }

    fn build(&mut self) {
        let mut item_idx = HashMap::new();
        let mesh_library = self.base().get_mesh_library().unwrap();
        for idx in 0..mesh_library.get_item_list().len() {
            let name = mesh_library.get_item_name(idx as i32);
            item_idx.insert(name.to_string(), idx as i32);
        }
        let floor_idx = item_idx[&"floor".to_string()];
        let wall_idx = item_idx[&"wall".to_string()];
        let goal_idx = item_idx[&"goal".to_string()];

        self.base_mut().clear();
        for x in 0..self.map.dimensions().x {
            for y in 0..self.map.dimensions().y {
                let tiles = self.map[Vector2::new(x, y)];

                if tiles.contains(Tiles::Floor) {
                    self.base_mut()
                        .set_cell_item(Vector3i::new(x, -1, y), floor_idx);
                }

                let item_id = match tiles & !Tiles::Floor {
                    Tiles::Wall => wall_idx,
                    Tiles::Goal => goal_idx,
                    _ => continue,
                };
                self.base_mut()
                    .set_cell_item(Vector3i::new(x, 0, y), item_id);
            }
        }

        let box_scene: Gd<PackedScene> = load("res://scenes/box.tscn");
        for position in self.map.box_positions() {
            let mut instance: Gd<Node3D> = box_scene.instantiate().unwrap().cast();
            instance.set_global_position(Vector3::new(
                position.x as f32 + 0.5,
                0.5,
                position.y as f32 + 0.5,
            ));
            self.base()
                .get_node_as::<Node3D>("Boxes")
                .add_child(&instance);
        }

        let mut player = self.base().get_node_as::<Node3D>("Player");
        player.set_global_position(Vector3::new(
            self.map.player_position().x as f32 + 0.5,
            0.5,
            self.map.player_position().y as f32 + 0.5,
        ));
    }
}
