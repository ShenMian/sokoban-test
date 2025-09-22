use std::str::FromStr;

use godot::classes::{GridMap, IGridMap};
use godot::prelude::*;
use nalgebra::Vector2;
use soukoban::{Actions, Level, Map, Tiles, deadlock::calculate_static_deadlocks};

use crate::utils::*;

#[derive(GodotClass)]
#[class(base=GridMap)]
struct LevelMap {
    #[var(set = set_show_deadlocks)]
    #[export]
    show_deadlocks: bool,

    level: Level,

    floor_id: i32,
    wall_id: i32,
    goal_id: i32,
    deadlock_id: i32,
    box_scene: Gd<PackedScene>,

    base: Base<GridMap>,
}

#[godot_api]
impl IGridMap for LevelMap {
    fn init(base: Base<GridMap>) -> Self {
        let map = Map::from_actions(Actions::from_str("R").unwrap()).unwrap();
        Self {
            show_deadlocks: true,
            level: Level::from_map(map),
            floor_id: -1,
            wall_id: -1,
            goal_id: -1,
            deadlock_id: -1,
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
    fn load_from_string(&mut self, lurd: GString) {
        let Ok(actions) = Actions::from_str(&lurd.to_string()) else {
            godot_print!("failed to parse actions from string");
            return;
        };
        let Ok(map) = Map::from_actions(actions) else {
            godot_print!("failed to create map from actions");
            return;
        };
        self.level = Level::from_map(map);
        self.build();
    }

    #[func]
    fn dimensions(&self) -> Vector2i {
        to_gd_vec2(&self.map().dimensions())
    }

    #[func]
    fn player_position(&self) -> Vector2i {
        to_gd_vec2(&self.map().player_position())
    }

    #[func]
    fn box_positions(&self) -> Array<Vector2i> {
        self.map().box_positions().iter().map(to_gd_vec2).collect()
    }

    #[func]
    fn goal_positions(&self) -> Array<Vector2i> {
        self.map().goal_positions().iter().map(to_gd_vec2).collect()
    }

    #[func]
    fn is_solved(&self) -> bool {
        self.map().is_solved()
    }

    #[func]
    fn move_by(&mut self, direction: i32) {
        let direction = match direction {
            0 => soukoban::direction::Direction::Up,
            1 => soukoban::direction::Direction::Down,
            2 => soukoban::direction::Direction::Left,
            3 => soukoban::direction::Direction::Right,
            _ => unreachable!(),
        };

        let box_positions = self.map().box_positions().clone();
        if let Err(err) = self.level.do_action(direction) {
            godot_print!("failed to do action: {}", err);
        }

        let new_box_positions = self.map().box_positions().clone();

        let box_position = box_positions.difference(&new_box_positions).next();
        let new_box_position = new_box_positions.difference(&box_positions).next();
        debug_assert!(box_position.is_some() == new_box_position.is_some());

        let player_position = self.map().player_position();
        self.signals()
            .player_move()
            .emit(to_gd_vec2(&player_position), new_box_position.is_some());

        if let (Some(box_position), Some(new_box_position)) = (box_position, new_box_position) {
            self.signals()
                .box_move()
                .emit(to_gd_vec2(box_position), to_gd_vec2(new_box_position));
        }

        if self.map().is_solved() {
            self.signals().solved().emit();
        }
    }

    fn map(&self) -> &Map {
        self.level.map()
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
        self.floor_id = floor_id.unwrap();
        self.wall_id = wall_id.unwrap();
        self.goal_id = goal_id.unwrap();
        self.deadlock_id = deadlock_id.unwrap();

        let mut boxes = self.base().get_node_as::<Node3D>("Boxes");
        for mut child in boxes.get_children().iter_shared() {
            child.queue_free();
        }

        self.base_mut().clear();
        for x in 0..self.map().dimensions().x {
            for y in 0..self.map().dimensions().y {
                let tiles = self.map()[Vector2::new(x, y)];

                if tiles.contains(Tiles::Floor) {
                    let floor_id = self.floor_id;
                    self.base_mut()
                        .set_cell_item(Vector3i::new(x, -1, y), floor_id);
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

        if self.show_deadlocks {
            self.show_deadlocks();
        }
    }

    #[func]
    fn set_show_deadlocks(&mut self, show: bool) {
        if show {
            self.show_deadlocks();
        } else {
            self.hide_deadlocks();
        }
    }

    fn show_deadlocks(&mut self) {
        let deadlock_id = self.deadlock_id;
        let deadlocks = calculate_static_deadlocks(self.map());
        for position in deadlocks {
            self.base_mut()
                .set_cell_item(Vector3i::new(position.x, 0, position.y), deadlock_id);
        }
    }

    fn hide_deadlocks(&mut self) {
        for position in self
            .base()
            .get_used_cells_by_item(self.deadlock_id)
            .iter_shared()
        {
            self.base_mut().set_cell_item(position, -1);
        }
    }
}
