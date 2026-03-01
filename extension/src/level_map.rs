use std::{collections::HashMap, fs::File, io::BufReader, str::FromStr};

use godot::{
    classes::{ArrayMesh, GridMap, IGridMap, MeshLibrary, StandardMaterial3D},
    meta::ToGodot as _,
    prelude::*,
};
use nalgebra::Vector2;
use soukoban::{
    Actions, Level, Map, Tiles,
    deadlock::compute_static_deadlocks,
    direction::{DirectedPosition, Direction},
    path_finding,
    solver::Strategy,
};

use crate::utils::{ToGodot, ToNalgebra};

#[derive(GodotConvert, Var, Export, Default, Clone)]
#[godot(via = i32)]
pub enum PathfindingStrategy {
    #[default]
    PushOptimal,
    MoveOptimal,
}

#[derive(GodotClass)]
#[class(base=GridMap)]
struct LevelMap {
    #[export]
    #[var(get, set = set_checkerboard_shading)]
    checkerboard_shading: bool,

    #[export]
    #[var(get, set = set_deadlock_hint)]
    deadlock_hint: bool,

    #[export]
    #[var(get, set = set_deadlock_tint)]
    deadlock_tint: Color,

    #[export]
    #[var(get, set = set_pushable_hint)]
    pushable_hint: bool,

    #[export]
    pathfinding_strategy: PathfindingStrategy,

    #[export]
    floor_item_id: i32,
    #[export]
    wall_item_id: i32,
    #[export]
    goal_item_id: i32,

    floor_dark_item_id: i32,
    deadlock_item_id: i32,
    deadlock_dark_item_id: i32,

    selected_box: Option<Gd<Node3D>>,
    waypoints: HashMap<DirectedPosition, DirectedPosition>,
    costs: HashMap<DirectedPosition, i32>,

    level: Level,

    base: Base<GridMap>,
}

#[godot_api]
impl IGridMap for LevelMap {
    fn init(base: Base<GridMap>) -> Self {
        let level = Level::from_map(Map::from_actions(Actions::from_str("R").unwrap()).unwrap());
        Self {
            checkerboard_shading: true,
            deadlock_hint: true,
            deadlock_tint: Color::from_rgb(0.5, 0.5, 0.5),
            pushable_hint: true,
            pathfinding_strategy: PathfindingStrategy::default(),
            floor_item_id: GridMap::INVALID_CELL_ITEM,
            wall_item_id: GridMap::INVALID_CELL_ITEM,
            goal_item_id: GridMap::INVALID_CELL_ITEM,
            floor_dark_item_id: GridMap::INVALID_CELL_ITEM,
            deadlock_item_id: GridMap::INVALID_CELL_ITEM,
            deadlock_dark_item_id: GridMap::INVALID_CELL_ITEM,
            selected_box: None,
            waypoints: HashMap::new(),
            costs: HashMap::new(),
            level,
            base,
        }
    }
}

#[godot_api]
impl LevelMap {
    #[signal]
    fn player_moved(to: Vector2i, pushed: bool);

    #[signal]
    fn box_moved(from: Vector2i, to: Vector2i);

    #[signal]
    fn solved();

    /// Loads levels from an XSB file.
    #[func]
    fn load_collection(path: GString) -> Array<VarDictionary> {
        let path = path.to_string();
        let reader = BufReader::new(File::open(&path).unwrap());
        let mut levels = Array::new();
        for result in Level::load_from_reader(reader) {
            match result {
                Ok(level) => {
                    let mut dict = VarDictionary::new();
                    dict.set("map", level.map().to_string());
                    for (key, value) in level.metadata() {
                        dict.set(key.as_str(), value.as_str());
                    }
                    levels.push(&dict);
                }
                Err(e) => {
                    godot_warn!("load_collection: failed to parse level: {}", e);
                }
            }
        }
        levels
    }

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
    fn pushable_box_positions(&self) -> Array<Vector2i> {
        path_finding::pushable_boxes(self.map())
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
    fn box_move_path(&self, box_position: Vector2i, to: Vector2i) -> Array<i32> {
        let box_position = box_position.to_na();
        let to = to.to_na();

        debug_assert!(self.map().box_positions().contains(&box_position));

        let mut best_dp = None;
        let mut min_cost = i32::MAX;

        for &dp in self.waypoints.keys() {
            if dp.position() == to
                && let Some(&cost) = self.costs.get(&dp)
                && cost < min_cost
            {
                min_cost = cost;
                best_dp = Some(dp);
            }
        }

        let mut best_path = Array::new();
        if let Some(dp) = best_dp {
            let box_path = path_finding::construct_box_path(dp, &self.waypoints);
            let player_path = path_finding::construct_player_path(
                self.map(),
                self.map().player_position(),
                &box_path,
            );

            for direction in player_path
                .windows(2)
                .map(|p| Direction::try_from(p[1] - p[0]).unwrap())
            {
                best_path.push(direction as i32);
            }
        }

        best_path
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
            .player_moved()
            .emit(player_position.to_gd(), new_box_position.is_some());

        if let (Some(box_position), Some(new_box_position)) = (box_position, new_box_position) {
            self.signals()
                .box_moved()
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
        if self.floor_dark_item_id == GridMap::INVALID_CELL_ITEM {
            let mut mesh_library = self.base().get_mesh_library().unwrap();
            self.floor_dark_item_id = self.create_floor(&mut mesh_library, "floor_dark", |color| {
                color.darkened(0.15)
            });

            let deadlock_tint = self.deadlock_tint;
            self.deadlock_item_id =
                self.create_floor(&mut mesh_library, "floor_deadlock", |color| {
                    color * deadlock_tint
                });
            self.deadlock_dark_item_id =
                self.create_floor(&mut mesh_library, "floor_deadlock_dark", |color| {
                    color.darkened(0.15) * deadlock_tint
                });
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
                            self.deadlock_dark_item_id
                        } else {
                            self.deadlock_item_id
                        }
                    } else if self.checkerboard_shading && (x + y) % 2 == 1 {
                        self.floor_dark_item_id
                    } else {
                        self.floor_item_id
                    };
                    self.base_mut()
                        .set_cell_item(Vector3i::new(x, -1, y), tile_id);
                }
                if tiles.intersects(Tiles::Wall | Tiles::Goal) {
                    let item_id = match tiles & !Tiles::Floor {
                        Tiles::Wall => self.wall_item_id,
                        Tiles::Goal => self.goal_item_id,
                        _ => continue,
                    };
                    self.base_mut()
                        .set_cell_item(Vector3i::new(x, 0, y), item_id);
                }
            }
        }

        self.clear_boxes();
        let mut boxes = self.base().get_node_as::<Node3D>("Boxes");
        let box_scene: Gd<PackedScene> = load("res://scenes/box.tscn");
        for position in self.map().box_positions() {
            let mut r#box = box_scene.instantiate_as::<Node3D>();
            r#box.set_global_position(Vector3::new(position.x as f32, 0.0, position.y as f32));
            let box_node = r#box.to_variant();
            r#box.connect(
                "selected",
                &self.to_gd().callable("on_box_selected").bind(&[box_node]),
            );
            r#box.connect("unselected", &self.to_gd().callable("on_box_unselected"));
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
    fn on_box_selected(&mut self, r#box: Gd<Node3D>) {
        self.deselect_box();
        self.selected_box = Some(r#box.clone());

        let box_position = Vector2::<i32>::new(
            r#box.get_global_position().x.round() as i32,
            r#box.get_global_position().z.round() as i32,
        );

        let strategy = match self.pathfinding_strategy {
            PathfindingStrategy::PushOptimal => Strategy::OptimalPush,
            PathfindingStrategy::MoveOptimal => Strategy::OptimalMove,
        };

        let start = std::time::Instant::now();
        let (mut waypoints, costs) =
            path_finding::box_move_waypoints(self.map(), box_position, strategy);
        let elapsed = start.elapsed();

        godot_print!("found {} waypoints in {:?}", waypoints.len(), elapsed);

        if self.deadlock_hint {
            let deadlocks = compute_static_deadlocks(self.map());
            waypoints.retain(|dp, _| !deadlocks.contains(&dp.position()));
        }

        let mut container = self.base_mut().get_node_as::<Node3D>("Waypoints");
        let waypoint_scene: Gd<PackedScene> = load("res://scenes/waypoint.tscn");
        for position in waypoints.keys().map(|dp| dp.position()) {
            let mut waypoint = waypoint_scene.instantiate_as::<Node3D>();
            waypoint.set_global_position(Vector3::new(position.x as f32, 0.01, position.y as f32));
            waypoint.connect(
                "clicked",
                &self.to_gd().callable("on_waypoint_clicked").bind(&[
                    box_position.to_gd().to_variant(),
                    position.to_gd().to_variant(),
                ]),
            );
            container.add_child(&waypoint);
        }

        self.waypoints = waypoints;
        self.costs = costs;
    }

    #[func]
    fn on_box_unselected(&mut self) {
        self.deselect_box();
    }

    #[func]
    fn deselect_box(&mut self) {
        if let Some(mut selected_box) = self.selected_box.take() {
            selected_box.call("deselect", &[]);
        }
        self.clear_waypoints();
    }

    fn clear_boxes(&self) {
        let boxes = self.base().get_node_as::<Node3D>("Boxes");
        for mut child in boxes.get_children().iter_shared() {
            child.queue_free();
        }
    }

    #[func]
    fn clear_waypoints(&self) {
        let container = self.base().get_node_as::<Node3D>("Waypoints");
        for mut child in container.get_children().iter_shared() {
            child.queue_free();
        }
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

    #[func]
    fn set_pushable_hint(&mut self, enable: bool) {
        self.pushable_hint = enable;
        let boxes = self.base().get_node_as::<Node3D>("Boxes");
        for mut r#box in boxes.get_children().iter_shared() {
            let callable = self.to_gd().callable("update_pushable_hint");
            if enable {
                r#box.connect("move_finished", &callable);
            } else {
                r#box.disconnect("move_finished", &callable);
            }
        }
        self.update_pushable_hint();
    }

    #[func]
    fn update_pushable_hint(&mut self) {
        if self.pushable_hint {
            // Disable non-pushable boxes
            let pushable_positions = self.pushable_box_positions();
            let boxes = self.base().get_node_as::<Node3D>("Boxes");
            for mut r#box in boxes.get_children().iter_shared() {
                let grid_position: Vector2i = r#box.call("grid_position", &[]).to();
                let is_pushable = pushable_positions
                    .iter_shared()
                    .any(|position| position == grid_position);
                r#box.set("disabled", &(!is_pushable).to_variant());
            }
        } else {
            // Enables all boxes
            let boxes = self.base().get_node_as::<Node3D>("Boxes");
            for mut r#box in boxes.get_children().iter_shared() {
                r#box.set("disabled", &false.to_variant());
            }
        }
    }

    #[func]
    fn set_deadlock_tint(&mut self, color: Color) {
        self.deadlock_tint = color;
        self.floor_dark_item_id = GridMap::INVALID_CELL_ITEM;
        self.build();
    }

    fn create_floor<F>(&self, mesh_library: &mut Gd<MeshLibrary>, name: &str, f: F) -> i32
    where
        F: Fn(Color) -> Color,
    {
        let next_id = mesh_library.get_last_unused_item_id();
        mesh_library.create_item(next_id);
        mesh_library.set_item_name(next_id, name);

        let mesh = mesh_library.get_item_mesh(self.floor_item_id).unwrap();

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

        let transform = mesh_library.get_item_mesh_transform(self.floor_item_id);
        mesh_library.set_item_mesh_transform(next_id, transform);

        next_id
    }
}
