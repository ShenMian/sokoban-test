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
        Self {
            map: Map::from_actions(Actions::from_str("R").unwrap()).unwrap(),
            base,
        }
    }
}

#[godot_api]
impl LevelMap {
    #[func]
    fn load_from_string(&mut self, lurd: GString) {
        let Ok(actions) = Actions::from_str(&lurd.to_string()) else {
            godot_print!("failed to parse actions from string");
            return;
        };
        let Ok(map) = Map::from_actions(actions) else {
            godot_print!("failed to create map from actions");
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
        let mut item_ids = HashMap::new();
        let mesh_library = self.base().get_mesh_library().unwrap();
        for id in (0..mesh_library.get_item_list().len()).map(|id| id as i32) {
            let name = mesh_library.get_item_name(id);
            let tile = match name.to_string().as_str() {
                "floor" => Tiles::Floor,
                "wall" => Tiles::Wall,
                "goal" => Tiles::Goal,
                _ => continue,
            };
            item_ids.insert(tile, id);
        }
        assert_eq!(item_ids.len(), 3, "missing required mesh items");

        let mut boxes = self.base().get_node_as::<Node3D>("Boxes");
        for r#box in boxes.get_children().iter_shared() {
            boxes.remove_child(&r#box);
        }

        self.base_mut().clear();
        for x in 0..self.map.dimensions().x {
            for y in 0..self.map.dimensions().y {
                let tiles = self.map[Vector2::new(x, y)];

                if tiles.contains(Tiles::Floor) {
                    let floor_id = item_ids[&Tiles::Floor];
                    self.base_mut()
                        .set_cell_item(Vector3i::new(x, -1, y), floor_id);
                }
                if tiles.intersects(Tiles::Wall | Tiles::Goal) {
                    let item_id = item_ids[&(tiles & !Tiles::Floor)];
                    self.base_mut()
                        .set_cell_item(Vector3i::new(x, 0, y), item_id);
                }
            }
        }

        let box_scene: Gd<PackedScene> = load("res://scenes/box.tscn");
        for position in self.map.box_positions() {
            let mut r#box: Gd<Node3D> = box_scene.instantiate().unwrap().cast();
            r#box.set_global_position(Vector3::new(position.x as f32, 0.0, position.y as f32));
            boxes.add_child(&r#box);
        }

        let mut player = self.base().get_node_as::<Node3D>("Player");
        player.set_global_position(Vector3::new(
            self.map.player_position().x as f32,
            0.0,
            self.map.player_position().y as f32,
        ));
    }
}
