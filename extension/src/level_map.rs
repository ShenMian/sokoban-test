use std::str::FromStr;

use godot::classes::{GridMap, IGridMap};
use godot::prelude::*;
use nalgebra::Vector2;
use soukoban::{Actions, Map, Tiles, deadlock::calculate_static_deadlocks};

use crate::utils::*;

#[derive(GodotClass)]
#[class(base=GridMap)]
struct LevelMap {
    map: Map,
    box_scene: Gd<PackedScene>,
    base: Base<GridMap>,
}

#[godot_api]
impl IGridMap for LevelMap {
    fn init(base: Base<GridMap>) -> Self {
        Self {
            map: Map::from_actions(Actions::from_str("R").unwrap()).unwrap(),
            box_scene: load("res://scenes/box.tscn"),
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
        to_gd_vec2(&self.map.dimensions())
    }

    #[func]
    fn player_position(&self) -> Vector2i {
        to_gd_vec2(&self.map.player_position())
    }

    #[func]
    fn box_positions(&self) -> Array<Vector2i> {
        self.map.box_positions().iter().map(to_gd_vec2).collect()
    }

    fn build(&mut self) {
        let mut floor_id = None;
        let mut wall_id = None;
        let mut goal_id = None;
        let mut deadlock_id = None;

        let mesh_library = self.base().get_mesh_library().unwrap();
        for id in (0..mesh_library.get_item_list().len()).map(|id| id as i32) {
            let name = mesh_library.get_item_name(id);
            match name.to_string().as_str() {
                "floor" => floor_id = Some(id),
                "wall" => wall_id = Some(id),
                "goal" => goal_id = Some(id),
                "deadlock" => deadlock_id = Some(id),
                _ => continue,
            }
        }
        assert!(
            floor_id.is_some() && wall_id.is_some() && goal_id.is_some() && deadlock_id.is_some(),
        );
        let floor_id = floor_id.unwrap();
        let wall_id = wall_id.unwrap();
        let goal_id = goal_id.unwrap();
        let deadlock_id = deadlock_id.unwrap();

        let mut boxes = self.base().get_node_as::<Node3D>("Boxes");
        for mut child in boxes.get_children().iter_shared() {
            child.queue_free();
        }

        self.base_mut().clear();
        for x in 0..self.map.dimensions().x {
            for y in 0..self.map.dimensions().y {
                let tiles = self.map[Vector2::new(x, y)];

                if tiles.contains(Tiles::Floor) {
                    self.base_mut()
                        .set_cell_item(Vector3i::new(x, -1, y), floor_id);
                }
                if tiles.intersects(Tiles::Wall | Tiles::Goal) {
                    let item_id = match tiles & !Tiles::Floor {
                        Tiles::Wall => wall_id,
                        Tiles::Goal => goal_id,
                        _ => continue,
                    };
                    self.base_mut()
                        .set_cell_item(Vector3i::new(x, 0, y), item_id);
                }
            }
        }

        // let deadlocks = calculate_static_deadlocks(&self.map);
        // for position in deadlocks {
        //     self.base_mut()
        //         .set_cell_item(Vector3i::new(position.x, 0, position.y), deadlock_id);
        // }

        for position in self.map.box_positions() {
            let mut r#box = self.box_scene.instantiate_as::<Node3D>();
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
