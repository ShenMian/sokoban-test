use std::str::FromStr;

use godot::{
    classes::{ArrayMesh, GridMap, IGridMap, MeshLibrary, StandardMaterial3D},
    prelude::*,
};
use nalgebra::Vector2;
use soukoban::{
    Actions, Level, Map, Tiles, deadlock::compute_static_deadlocks, direction::Direction,
};

use crate::utils::ToGodot;

#[derive(GodotClass)]
#[class(base=GridMap)]
struct LevelMap {
    #[var(set = set_deadlock_hint)]
    #[export]
    deadlock_hint: bool,

    #[var(set = set_checkerboard_shading)]
    #[export]
    checkerboard_shading: bool,

    level: Level,

    floor_id: i32,
    floor_dark_id: i32,
    floor_deadlock_id: i32,
    floor_deadlock_dark_id: i32,
    wall_id: i32,
    goal_id: i32,

    box_scene: Gd<PackedScene>,

    base: Base<GridMap>,
}

#[godot_api]
impl IGridMap for LevelMap {
    fn init(base: Base<GridMap>) -> Self {
        let map = Map::from_actions(Actions::from_str("R").unwrap()).unwrap();
        Self {
            deadlock_hint: true,
            checkerboard_shading: true,
            level: Level::from_map(map),
            floor_id: -1,
            floor_dark_id: -1,
            floor_deadlock_id: -1,
            floor_deadlock_dark_id: -1,
            wall_id: -1,
            goal_id: -1,
            box_scene: load("res://scenes/box.tscn"),
            base,
        }
    }
}

#[godot_api]
impl LevelMap {
    #[signal]
    fn player_move(to: Vector2i, is_pushing: bool);

    #[signal]
    fn box_move(from: Vector2i, to: Vector2i);

    #[signal]
    fn solved();

    #[func]
    fn load_from_string(&mut self, string: GString) {
        if let Ok(map) = Map::from_str(&string.to_string()) {
            self.level = Level::from_map(map);
            self.build();
        } else if let Ok(actions) = Actions::from_str(&string.to_string()) {
        let Ok(map) = Map::from_actions(actions) else {
                godot_warn!("failed to create map from actions");
            return;
        };
        self.level = Level::from_map(map);
        self.build();
        } else {
            godot_warn!("failed to parse map or actions from string: '{string}'");
        }
    }

    #[func]
    fn export_to_string(&self) -> GString {
        (&self.map().to_string()).into()
    }

    #[func]
    fn dimensions(&self) -> Vector2i {
        self.map().dimensions().to_gd()
    }

    #[func]
    fn player_position(&self) -> Vector2i {
        self.map().player_position().to_gd()
    }

    #[func]
    fn box_positions(&self) -> Array<Vector2i> {
        self.map()
            .box_positions()
            .iter()
            .map(ToGodot::to_gd)
            .collect()
    }

    #[func]
    fn goal_positions(&self) -> Array<Vector2i> {
        self.map()
            .goal_positions()
            .iter()
            .map(ToGodot::to_gd)
            .collect()
    }

    #[func]
    fn is_solved(&self) -> bool {
        self.map().is_solved()
    }

    #[func]
    fn move_by(&mut self, direction: i32) {
        let direction = match direction {
            0 => Direction::Up,
            1 => Direction::Down,
            2 => Direction::Left,
            3 => Direction::Right,
            _ => unreachable!(),
        };

        let box_positions = self.map().box_positions().clone();
        let _ = self.level.execute(direction);

        let new_box_positions = self.map().box_positions().clone();

        let box_position = box_positions.difference(&new_box_positions).next();
        let new_box_position = new_box_positions.difference(&box_positions).next();
        debug_assert!(box_position.is_some() == new_box_position.is_some());

        let player_position = self.map().player_position();
        self.signals()
            .player_move()
            .emit(player_position.to_gd(), new_box_position.is_some());

        if let (Some(box_position), Some(new_box_position)) = (box_position, new_box_position) {
            self.signals()
                .box_move()
                .emit(box_position.to_gd(), new_box_position.to_gd());
        }

        if self.map().is_solved() {
            self.signals().solved().emit();
        }
    }

    fn map(&self) -> &Map {
        self.level.map()
    }

    fn build(&mut self) {
        if self.floor_id == -1 {
            let mut mesh_library = self.base().get_mesh_library().unwrap();

            let mut floor_id = None;
            let mut wall_id = None;
            let mut goal_id = None;
            for id in 0..mesh_library.get_item_list().len() as i32 {
                let name = mesh_library.get_item_name(id);
                match name.to_string().as_str() {
                    "floor" => floor_id = Some(id),
                    "wall" => wall_id = Some(id),
                    "goal" => goal_id = Some(id),
                    _ => continue,
                }
            }
            self.floor_id = floor_id.unwrap();
            self.wall_id = wall_id.unwrap();
            self.goal_id = goal_id.unwrap();

            self.floor_dark_id = self.create_floor(&mut mesh_library, "floor_dark", |color| {
                color.darkened(0.15)
            });
            self.floor_deadlock_id =
                self.create_floor(&mut mesh_library, "floor_deadlock", |color| {
                    color.darkened(0.3)
                });
            self.floor_deadlock_dark_id =
                self.create_floor(&mut mesh_library, "floor_deadlock_dark", |color| {
                    color.darkened(0.3 + 0.15)
                });
        }

        let mut boxes = self.base().get_node_as::<Node3D>("Boxes");
        for mut child in boxes.get_children().iter_shared() {
            child.queue_free();
        }

        let deadlocks = compute_static_deadlocks(self.map());

        self.base_mut().clear();
        for x in 0..self.map().dimensions().x {
            for y in 0..self.map().dimensions().y {
                let position = Vector2::new(x, y);
                let tiles = self.map()[position];

                if tiles.contains(Tiles::Floor) {
                    let tile_id = if self.deadlock_hint && deadlocks.contains(&position) {
                        if self.checkerboard_shading && (x + y) % 2 == 1 {
                            self.floor_deadlock_dark_id
                        } else {
                            self.floor_deadlock_id
                        }
                    } else {
                        if self.checkerboard_shading && (x + y) % 2 == 1 {
                            self.floor_dark_id
                        } else {
                            self.floor_id
                        }
                    };
                    self.base_mut()
                        .set_cell_item(Vector3i::new(x, -1, y), tile_id);
                }
                if tiles.intersects(Tiles::Wall | Tiles::Goal) {
                    let item_id = match tiles & !Tiles::Floor {
                        Tiles::Wall => self.wall_id,
                        Tiles::Goal => self.goal_id,
                        _ => continue,
                    };
                    self.base_mut()
                        .set_cell_item(Vector3i::new(x, 0, y), item_id);
                }
            }
        }

        for position in self.map().box_positions() {
            let mut r#box = self.box_scene.instantiate_as::<Node3D>();
            r#box.set_global_position(Vector3::new(position.x as f32, 0.0, position.y as f32));
            boxes.add_child(&r#box);
        }

        let mut player = self.base().get_node_as::<Node3D>("Player");
        player.set_global_position(Vector3::new(
            self.map().player_position().x as f32,
            0.0,
            self.map().player_position().y as f32,
        ));
    }

    #[func]
    fn set_deadlock_hint(&mut self, enable: bool) {
        self.deadlock_hint = enable;
        self.build();
    }

    #[func]
    fn set_checkerboard_shading(&mut self, enable: bool) {
        self.checkerboard_shading = enable;
        self.build();
    }

    fn create_floor(
        &self,
        mesh_library: &mut Gd<MeshLibrary>,
        name: &str,
        f: fn(Color) -> Color,
    ) -> i32 {
        let next_id = mesh_library.get_last_unused_item_id();
        mesh_library.create_item(next_id);
        mesh_library.set_item_name(next_id, name);

        let mesh = mesh_library.get_item_mesh(self.floor_id).unwrap();

        let material = mesh.surface_get_material(0).unwrap();
        let standard_material = material.clone().cast::<StandardMaterial3D>();
        let mut new_standard_material = standard_material
            .duplicate()
            .unwrap()
            .cast::<StandardMaterial3D>();

        let color = new_standard_material.get_albedo();
        new_standard_material.set_albedo(f(color));

        let mut new_mesh = mesh.duplicate().unwrap().cast::<ArrayMesh>();
        new_mesh.surface_set_material(0, &new_standard_material);

        mesh_library.set_item_mesh(next_id, &new_mesh);

        let transform = mesh_library.get_item_mesh_transform(self.floor_id);
        mesh_library.set_item_mesh_transform(next_id, transform);

        next_id
    }
}
