use std::{
    collections::{HashMap, HashSet},
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
    solver::Solver,
};

use crate::{
    convert::{ToGodot, ToNalgebra},
    direction::Direction,
    strategy::Strategy,
};

/// Solver search algorithms.
#[derive(GodotConvert, Var, Export, Default, Clone, Copy, PartialEq, Eq, Debug)]
#[godot(via = i32)]
pub enum Algorithm {
    /// A* search algorithm.
    #[default]
    AStar,
    /// IDA* search algorithm.
    IDAStar,
}

/// Solver thread stack size in bytes (64 MB).
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
    #[var(set = set_deadlock_tint)]
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

    theme_floor_item_id: i32,
    theme_wall_item_id: i32,
    theme_goal_item_id: i32,

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
            theme_floor_item_id: GridMap::INVALID_CELL_ITEM,
            theme_wall_item_id: GridMap::INVALID_CELL_ITEM,
            theme_goal_item_id: GridMap::INVALID_CELL_ITEM,
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

    fn ready(&mut self) {
        self.create_theme_variants();
    }
}

#[godot_api]
impl LevelMap {
    /// Emitted when the player moves.
    #[signal]
    fn player_moved(to: Vector2i, pushed: bool);

    /// Emitted when a box moves.
    #[signal]
    fn box_moved(from: Vector2i, to: Vector2i);

    /// Emitted when a box enters a goal.
    #[signal]
    fn box_enter_goal(position: Vector2i);

    /// Emitted when a box leaves a goal.
    #[signal]
    fn box_leave_goal(position: Vector2i);

    /// Emitted when the level becomes solved.
    #[signal]
    fn solved();

    /// Emitted when the background solver completes successfully.
    #[signal]
    fn solve_completed(directions: Array<i32>);

    /// Emitted when the background solver fails.
    #[signal]
    fn solve_failed(error: GString);

    /// Loads levels from an XSB file.
    #[func]
    pub fn load_collection(path: String) -> Array<VarDictionary> {
        let mut file = FileAccess::open(&path, ModeFlags::READ).unwrap();
        let len = file.get_length() as i64;
        let buffer = file.get_buffer(len).to_vec();
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
    pub fn load_from_file(&mut self, path: String, index: i32) {
        let mut file = FileAccess::open(&path, ModeFlags::READ).unwrap();
        let len = file.get_length() as i64;
        let buffer = file.get_buffer(len).to_vec();
        let reader = BufReader::new(Cursor::new(buffer));

        self.level = Level::load_nth_from_reader(reader, index as usize).unwrap();
        self.build();
    }

    #[func]
    pub fn load_from_string(&mut self, string: String) {
        if let Ok(level) = Level::from_str(&string) {
            self.level = level;
            self.build();
        } else if let Ok(actions) = Actions::from_str(&string) {
            let Ok(map) = Map::from_actions(actions) else {
                godot_warn!("failed to create map from actions");
                return;
            };
            self.level = Level::from_map(map);
            self.fast_forward(string);
            self.undo_all();
            self.build();
        } else {
            godot_warn!("failed to parse level or actions from string: '{string}'");
        }
    }

    #[func]
    pub fn get_map_xsb(&self) -> String {
        self.map().to_string()
    }

    #[func]
    pub fn get_actions_lurd(&self) -> String {
        self.level.actions().to_string()
    }

    #[func]
    pub fn get_dimensions(&self) -> Vector2i {
        self.map().dimensions().to_gd()
    }

    #[func]
    pub fn get_player_position(&self) -> Vector2i {
        self.map().player_position().to_gd()
    }

    #[func]
    pub fn get_player_direction(&self) -> Direction {
        self.level
            .player_direction()
            .unwrap_or(direction::Direction::Down)
            .into()
    }

    #[func]
    pub fn get_box_positions(&self) -> Array<Vector2i> {
        self.map()
            .box_positions()
            .iter()
            .map(ToGodot::to_gd)
            .collect()
    }

    #[func]
    pub fn get_pushable_box_positions(&self) -> Array<Vector2i> {
        path_finding::compute_pushable_boxes(self.map())
            .iter()
            .map(ToGodot::to_gd)
            .collect()
    }

    #[func]
    pub fn get_goal_positions(&self) -> Array<Vector2i> {
        self.map()
            .goal_positions()
            .iter()
            .map(ToGodot::to_gd)
            .collect()
    }

    #[func]
    pub fn is_solved(&self) -> bool {
        self.map().is_solved()
    }

    #[func]
    pub fn get_box_move_path(&self, to: Vector2i) -> Array<i32> {
        let to = to.to_na();

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

        let mut directions = Array::new();
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
                directions.push(direction as i32);
            }
        }

        directions
    }

    #[func]
    pub fn get_box_path(&self, to: Vector2i) -> Array<Vector2i> {
        let to = to.to_na();

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

        let mut positions = Array::new();
        if let Some(dp) = best_dp {
            let box_path = path_finding::construct_box_path(dp, &self.waypoints);
            for position in box_path {
                positions.push(position.to_gd());
            }
        }

        positions
    }

    #[func]
    pub fn get_waypoint_positions(&mut self, box_position: Vector2i) -> Array<Vector2i> {
        let box_position = box_position.to_na();

        let start = std::time::Instant::now();
        let (mut waypoints, costs) = path_finding::compute_box_waypoints(
            self.map(),
            box_position,
            self.pathfinding_strategy.into(),
        );
        godot_print!(
            "found {} waypoints ({:?})",
            waypoints.len(),
            start.elapsed()
        );

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
    pub fn start_solve(&mut self, algorithm: Algorithm, strategy: Strategy) {
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
    pub fn poll_solve(&mut self) -> bool {
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
    pub fn cancel_solve(&mut self) {
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
    pub fn fast_forward(&mut self, lurd: String) {
        let actions = Actions::from_str(&lurd).expect("failed to parse actions");
        self.level
            .execute_batch(actions.0.into_iter().map(|action| action.direction()))
            .unwrap();
    }

    #[func]
    pub fn move_by(&mut self, direction: Direction) {
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
    pub fn undo(&mut self) {
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
    pub fn redo(&mut self) {
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
    pub fn undo_all(&mut self) {
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
    pub fn get_move_count(&self) -> i32 {
        self.level.actions().moves() as i32
    }

    #[func]
    pub fn get_push_count(&self) -> i32 {
        self.level.actions().pushes() as i32
    }

    #[func]
    pub fn get_status(&self) -> VarDictionary {
        let mut dict = VarDictionary::new();
        dict.set("move_count", self.get_move_count());
        dict.set("push_count", self.get_push_count());
        dict.set("can_undo", self.can_undo());
        dict.set("can_redo", self.can_redo());
        dict
    }

    #[func]
    pub fn rotate(&mut self) {
        self.level.rotate();
        self.build();
    }

    #[func]
    pub fn flip_horizontal(&mut self) {
        self.level.flip_horizontal();
        self.build();
    }

    #[func]
    pub fn get_lower_bounds(&self, strategy: Strategy) -> VarDictionary {
        let solver = Solver::new(self.map().clone(), strategy.into());
        let mut dict = VarDictionary::new();
        for (position, value) in solver.lower_bounds() {
            dict.set(position.to_gd(), &value.to_variant());
        }
        dict
    }

    #[func]
    pub fn get_tunnels(&self) -> Array<Vector2i> {
        let solver = Solver::new(self.map().clone(), Strategy::Quick.into());
        let mut positions = Array::new();
        let mut set = HashSet::new();
        for tunnel in solver.tunnels() {
            let box_position = tunnel.position();
            if set.insert(box_position) {
                positions.push(box_position.to_gd());
            }
        }
        positions
    }

    #[func]
    pub fn build(&mut self) {
        if !self.base().is_inside_tree() {
            return;
        }

        self.waypoints.clear();
        self.costs.clear();

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
                        self.theme_floor_item_id
                    };
                    self.base_mut()
                        .set_cell_item(Vector3i::new(x, -1, y), tile_id);
                }
                if tiles.intersects(Tiles::Wall | Tiles::Goal) {
                    let item_id = if tiles.contains(Tiles::Wall) {
                        self.theme_wall_item_id
                    } else if tiles.contains(Tiles::Goal) {
                        self.theme_goal_item_id
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
    pub fn set_deadlock_tint(&mut self, color: Color) {
        self.deadlock_tint = color;
        self.create_theme_variants();
        self.build();
    }

    #[func]
    pub fn create_theme_variants(&mut self) {
        let Some(mut mesh_library) = self.base().get_mesh_library() else {
            return;
        };

        let map_theme = self.base().get_node_as::<Node>("/root/MapTheme");
        let floor_color: Color = map_theme.get("floor_color").to();
        let wall_color: Color = map_theme.get("wall_color").to();
        let goal_color: Color = map_theme.get("goal_color").to();

        self.theme_floor_item_id = self.create_colored_variant(
            &mut mesh_library,
            self.floor_item_id,
            "theme_floor",
            |_| floor_color,
        );
        self.theme_wall_item_id =
            self.create_colored_variant(&mut mesh_library, self.wall_item_id, "theme_wall", |_| {
                wall_color
            });
        self.theme_goal_item_id =
            self.create_colored_variant(&mut mesh_library, self.goal_item_id, "theme_goal", |_| {
                goal_color
            });

        self.floor_dark_item_id = self.create_colored_variant(
            &mut mesh_library,
            self.theme_floor_item_id,
            "floor_dark",
            |color| color.darkened(0.15),
        );

        let deadlock_tint = self.deadlock_tint;
        self.deadlock_item_id = self.create_colored_variant(
            &mut mesh_library,
            self.theme_floor_item_id,
            "floor_deadlock",
            |color| color * deadlock_tint,
        );
        self.deadlock_dark_item_id = self.create_colored_variant(
            &mut mesh_library,
            self.theme_floor_item_id,
            "floor_deadlock_dark",
            |color| color.darkened(0.15) * deadlock_tint,
        );
    }

    fn map(&self) -> &Map {
        self.level.map()
    }

    fn create_colored_variant<F>(
        &self,
        mesh_library: &mut Gd<MeshLibrary>,
        source_id: i32,
        name: &str,
        f: F,
    ) -> i32
    where
        F: Fn(Color) -> Color,
    {
        debug_assert_ne!(source_id, GridMap::INVALID_CELL_ITEM);

        let mut next_id = -1;
        let items = mesh_library.get_item_list();
        for id in items.as_slice() {
            if mesh_library.get_item_name(*id) == name {
                next_id = *id;
                break;
            }
        }

        if next_id == -1 {
            next_id = mesh_library.get_last_unused_item_id();
            mesh_library.create_item(next_id);
            mesh_library.set_item_name(next_id, name);
        }

        let mesh = mesh_library
            .get_item_mesh(source_id)
            .unwrap()
            .cast::<ArrayMesh>();

        let material = mesh.surface_get_material(0).unwrap();
        let standard_material = material.clone().cast::<StandardMaterial3D>();
        let mut new_standard_material = standard_material.duplicate_resource();

        let color = new_standard_material.get_albedo();
        new_standard_material.set_albedo(f(color));
        new_standard_material.set("albedo_texture", &Variant::nil());
        new_standard_material.set("vertex_color_use_as_albedo", &false.to_variant());

        let mut new_mesh = mesh.duplicate_resource();
        new_mesh.surface_set_material(0, &new_standard_material);

        mesh_library.set_item_mesh(next_id, &new_mesh);

        let transform = mesh_library.get_item_mesh_transform(source_id);
        mesh_library.set_item_mesh_transform(next_id, transform);

        next_id
    }
}
