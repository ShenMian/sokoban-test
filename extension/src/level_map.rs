use std::{
    collections::HashMap,
    io::{BufReader, Cursor},
    str::FromStr,
    sync::{
        Arc, Mutex,
        atomic::{AtomicBool, Ordering},
    },
    thread,
};

use godot::{
    classes::{
        ArrayMesh, FileAccess, GridMap, IGridMap, MeshLibrary, StandardMaterial3D,
        file_access::ModeFlags,
    },
    meta::ToGodot as _,
    prelude::*,
};
use nalgebra::Vector2;
use soukoban::{
    Actions, Level, Map, SearchError, Tiles,
    deadlock::compute_static_deadlocks,
    direction::{self, DirectedPosition},
    path_finding,
    solver::{self, Solver},
};

use crate::convert::{ToGodot, ToNalgebra};

#[derive(GodotConvert, Var, Export, Default, Clone, Copy, PartialEq, Eq, Debug)]
#[godot(via = i32)]
pub enum Direction {
    #[default]
    Up,
    Down,
    Left,
    Right,
}

impl From<Direction> for direction::Direction {
    fn from(direction: Direction) -> Self {
        match direction {
            Direction::Up => direction::Direction::Up,
            Direction::Down => direction::Direction::Down,
            Direction::Left => direction::Direction::Left,
            Direction::Right => direction::Direction::Right,
        }
    }
}

#[derive(GodotConvert, Var, Export, Default, Clone, Copy, PartialEq, Eq, Debug)]
#[godot(via = i32)]
pub enum Strategy {
    #[default]
    Quick,
    PushOptimal,
    MoveOptimal,
}

impl From<Strategy> for solver::Strategy {
    fn from(strategy: Strategy) -> Self {
        match strategy {
            Strategy::Quick => solver::Strategy::Fast,
            Strategy::PushOptimal => solver::Strategy::OptimalPush,
            Strategy::MoveOptimal => solver::Strategy::OptimalMove,
        }
    }
}

#[derive(GodotConvert, Var, Export, Default, Clone, Copy, PartialEq, Eq, Debug)]
#[godot(via = i32)]
pub enum Algorithm {
    #[default]
    AStar,
    IDAStar,
}

/// Stack size for the solver thread (64 MB).
const SOLVER_STACK_SIZE: usize = 64 * 1024 * 1024;

#[derive(GodotClass)]
#[class(base=GridMap)]
struct LevelMap {
    level: Level,

    #[export]
    checkerboard_shading: bool,

    #[export]
    deadlock_hint: bool,

    #[export]
    #[var(get, set = set_deadlock_tint)]
    deadlock_tint: Color,

    #[export]
    pathfinding_strategy: Strategy,

    #[export]
    floor_item_id: i32,
    #[export]
    wall_item_id: i32,
    #[export]
    goal_item_id: i32,

    floor_dark_item_id: i32,
    deadlock_item_id: i32,
    deadlock_dark_item_id: i32,

    waypoints: HashMap<DirectedPosition, DirectedPosition>,
    costs: HashMap<DirectedPosition, i32>,

    /// Active solver instance.
    solver: Option<Solver>,
    /// Shared storage for the background solver result.
    solver_result: Arc<Mutex<Option<Result<Actions, SearchError>>>>,
    /// Flag indicating that the solver thread has finished.
    solver_done: Arc<AtomicBool>,
    /// Handle to the solver thread (if running).
    solver_handle: Option<thread::JoinHandle<()>>,

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
            pathfinding_strategy: Strategy::default(),
            floor_item_id: GridMap::INVALID_CELL_ITEM,
            wall_item_id: GridMap::INVALID_CELL_ITEM,
            goal_item_id: GridMap::INVALID_CELL_ITEM,
            floor_dark_item_id: GridMap::INVALID_CELL_ITEM,
            deadlock_item_id: GridMap::INVALID_CELL_ITEM,
            deadlock_dark_item_id: GridMap::INVALID_CELL_ITEM,
            waypoints: HashMap::new(),
            costs: HashMap::new(),
            solver_result: Arc::new(Mutex::new(None)),
            solver_done: Arc::new(AtomicBool::new(false)),
            solver_handle: None,
            solver: None,
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
    fn box_enter_goal(position: Vector2i);

    #[signal]
    fn box_leave_goal(position: Vector2i);

    #[signal]
    fn solved();

    #[signal]
    fn solve_completed(directions: Array<i32>);

    #[signal]
    fn solve_failed(error: GString);

    /// Loads levels from an XSB file.
    #[func]
    fn load_collection(path: GString) -> Array<VarDictionary> {
        let path = path.to_string();
        let file = FileAccess::open(&path, ModeFlags::READ).unwrap();
        let buffer = file.get_buffer(file.get_length() as i64).to_vec();
        let reader = BufReader::new(Cursor::new(buffer));
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
    fn load_from_file(&mut self, path: GString, index: i32) {
        let file = FileAccess::open(&path, ModeFlags::READ).unwrap();
        let buffer = file.get_buffer(file.get_length() as i64).to_vec();
        let reader = BufReader::new(Cursor::new(buffer));
        self.level = Level::load_nth_from_reader(reader, index as usize).unwrap();
        self.build();
    }

    #[func]
    fn load_from_string(&mut self, string: GString) {
        if let Ok(level) = Level::from_str(&string.to_string()) {
            self.level = level;
            self.build();
        } else if let Ok(actions) = Actions::from_str(&string.to_string()) {
            let Ok(map) = Map::from_actions(actions) else {
                godot_warn!("failed to create map from actions");
                return;
            };
            self.level = Level::from_map(map);
            self.build();
        } else {
            godot_warn!("failed to parse level or actions from string: '{string}'");
        }
    }

    #[func]
    fn get_map(&self) -> GString {
        (&self.map().to_string()).into()
    }

    #[func]
    fn get_lurd(&self) -> GString {
        (&self.level.actions().to_string()).into()
    }

    #[func]
    fn get_dimensions(&self) -> Vector2i {
        self.map().dimensions().to_gd()
    }

    #[func]
    fn get_player_position(&self) -> Vector2i {
        self.map().player_position().to_gd()
    }

    #[func]
    fn get_box_positions(&self) -> Array<Vector2i> {
        self.map()
            .box_positions()
            .iter()
            .map(ToGodot::to_gd)
            .collect()
    }

    #[func]
    fn get_pushable_box_positions(&self) -> Array<Vector2i> {
        path_finding::compute_pushable_boxes(self.map())
            .iter()
            .map(ToGodot::to_gd)
            .collect()
    }

    #[func]
    fn get_goal_positions(&self) -> Array<Vector2i> {
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
    fn get_box_move_path(&self, from: Vector2i, to: Vector2i) -> Array<i32> {
        let box_position = from.to_na();
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
                .map(|p| direction::Direction::try_from(p[1] - p[0]).unwrap())
            {
                best_path.push(direction as i32);
            }
        }

        best_path
    }

    #[func]
    fn get_waypoint_positions(&mut self, box_position: Vector2i) -> Array<Vector2i> {
        let box_position = box_position.to_na();

        let start = std::time::Instant::now();
        let (mut waypoints, costs) = path_finding::compute_box_waypoints(
            self.map(),
            box_position,
            self.pathfinding_strategy.into(),
        );
        let elapsed = start.elapsed();

        godot_print!("found {} waypoints ({:?})", waypoints.len(), elapsed);

        if self.deadlock_hint {
            let deadlocks = compute_static_deadlocks(self.map());
            waypoints.retain(|dp, _| !deadlocks.contains(&dp.position()));
        }

        let mut positions = Array::new();
        for position in waypoints.keys().map(|dp| dp.position()) {
            positions.push(position.to_gd());
        }

        self.waypoints = waypoints;
        self.costs = costs;

        positions
    }

    /// Starts solving in a background thread with a custom stack size.
    #[func]
    fn start_solve(&mut self, algorithm: Algorithm, strategy: Strategy) {
        // Cancel any previously running solve.
        self.cancel_solve();

        let map = self.map().clone();
        let result_slot = Arc::clone(&self.solver_result);
        let done_flag = Arc::clone(&self.solver_done);

        done_flag.store(false, Ordering::Release);
        *result_slot.lock().unwrap() = None;

        let solver = Solver::new(map, strategy.into());
        self.solver = Some(solver.clone());

        let handle = thread::Builder::new()
            .name("solver".into())
            .stack_size(SOLVER_STACK_SIZE)
            .spawn(move || {
                let result = match algorithm {
                    Algorithm::AStar => solver.a_star_search(),
                    Algorithm::IDAStar => solver.ida_star_search(),
                };

                *result_slot.lock().unwrap() = Some(result);
                done_flag.store(true, Ordering::Release);
            })
            .expect("failed to spawn solver thread");

        self.solver_handle = Some(handle);
    }

    /// Polls for the solver result. Returns `true` while the solver is still
    /// running. When the solver finishes, emits `solve_completed` or
    /// `solve_failed` and returns `false`.
    #[func]
    fn poll_solve(&mut self) -> bool {
        if !self.solver_done.load(Ordering::Acquire) {
            return true;
        }

        if let Some(handle) = self.solver_handle.take() {
            let _ = handle.join();
        }
        self.solver = None;

        let result = self.solver_result.lock().unwrap().take();

        match result {
            Some(Ok(actions)) => {
                let mut directions = Array::new();
                for action in &*actions {
                    directions.push(action.direction() as i32);
                }
                self.signals().solve_completed().emit(&directions);
            }
            Some(Err(err)) => {
                self.signals()
                    .solve_failed()
                    .emit(&Into::<GString>::into(&err.to_string()));
            }
            None => unreachable!(),
        }

        false
    }

    /// Cancels a running solve (if any).
    #[func]
    fn cancel_solve(&mut self) {
        if let Some(solver) = self.solver.take() {
            solver.request_stop();
        }
        if let Some(handle) = self.solver_handle.take() {
            // Wait for the solver thread to exit.
            let _ = handle.join();
            self.solver_done.store(false, Ordering::Release);
            *self.solver_result.lock().unwrap() = None;
        }
    }

    #[func]
    fn move_by(&mut self, direction: Direction) {
        let direction: direction::Direction = direction.into();

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

        if let (Some(from), Some(to)) = (box_position, new_box_position) {
            self.signals().box_moved().emit(from.to_gd(), to.to_gd());

            match (
                self.map()[*from].contains(Tiles::Goal),
                self.map()[*to].contains(Tiles::Goal),
            ) {
                (false, true) => self.signals().box_enter_goal().emit(to.to_gd()),
                (true, false) => self.signals().box_leave_goal().emit(to.to_gd()),
                _ => {}
            }
        }

        if self.map().is_solved() {
            self.signals().solved().emit();
        }
    }

    /// Undoes actions until crossing the previous box-change boundary.
    #[func]
    fn undo(&mut self) {
        let initial_box_changes = self.level.actions().secondary_values().box_changes;
        while self.level.undo().is_ok() {
            if self.level.actions().secondary_values().box_changes < initial_box_changes {
                break;
            }
        }
        self.build();
    }

    /// Redoes actions until crossing the next box-change boundary.
    #[func]
    fn redo(&mut self) {
        let initial_box_changes = self.level.actions().secondary_values().box_changes;
        while self.level.redo().is_ok() {
            if self.level.actions().secondary_values().box_changes > initial_box_changes + 1 {
                let _ = self.level.undo();
                break;
            }
        }
        self.build();

        if self.map().is_solved() {
            self.signals().solved().emit();
        }
    }

    /// Undoes all actions.
    #[func]
    fn undo_all(&mut self) {
        while self.level.undo().is_ok() {}
        self.build();
    }

    /// Returns true if there are actions to undo.
    #[func]
    pub fn can_undo(&self) -> bool {
        !self.level.actions().is_empty()
    }

    /// Returns true if there are undone actions to redo.
    #[func]
    pub fn can_redo(&self) -> bool {
        !self.level.undone_actions().is_empty()
    }

    #[func]
    fn get_move_count(&self) -> i32 {
        self.level.actions().moves() as i32
    }

    #[func]
    fn get_push_count(&self) -> i32 {
        self.level.actions().pushes() as i32
    }

    #[func]
    fn get_status(&self) -> VarDictionary {
        let mut dict = VarDictionary::new();
        dict.set("move_count", self.get_move_count());
        dict.set("push_count", self.get_push_count());
        dict.set("can_undo", self.can_undo());
        dict.set("can_redo", self.can_redo());
        dict
    }

    #[func]
    fn rotate(&mut self) {
        self.level.rotate();
        self.build();
    }

    #[func]
    fn flip_horizontal(&mut self) {
        self.level.flip_horizontal();
        self.build();
    }

    #[func]
    fn get_lower_bounds(&self, strategy: Strategy) -> VarDictionary {
        let solver = Solver::new(self.map().clone(), strategy.into());
        let mut dict = VarDictionary::new();
        for (position, value) in solver.lower_bounds() {
            dict.set(position.to_gd(), value.to_variant());
        }
        dict
    }

    #[func]
    fn build(&mut self) {
        if !self.base().is_inside_tree() {
            return;
        }

        self.waypoints.clear();
        self.costs.clear();

        if self.floor_dark_item_id == GridMap::INVALID_CELL_ITEM {
            let Some(mut mesh_library) = self.base().get_mesh_library() else {
                return;
            };
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
                    let item_id = if tiles.contains(Tiles::Wall) {
                        self.wall_item_id
                    } else if tiles.contains(Tiles::Goal) {
                        self.goal_item_id
                    } else {
                        continue;
                    };
                    self.base_mut()
                        .set_cell_item(Vector3i::new(x, 0, y), item_id);
                }
            }
        }
    }

    #[func]
    fn set_deadlock_tint(&mut self, color: Color) {
        self.deadlock_tint = color;
        self.floor_dark_item_id = GridMap::INVALID_CELL_ITEM;
        self.build();
    }

    fn map(&self) -> &Map {
        self.level.map()
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
