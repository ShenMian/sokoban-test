use std::str::FromStr as _;

use godot::{
    classes::{DirAccess, FileAccess, ProjectSettings, file_access::ModeFlags},
    prelude::*,
};
use rusqlite::Connection;
use soukoban::{Actions, Level, level};

use crate::orm::{self, Snapshot};

#[derive(GodotClass)]
#[class(init, singleton)]
pub struct Database {
    connection: Option<Connection>,
}

#[godot_api]
impl Database {
    #[func]
    pub fn open(&mut self, path: String) {
        let is_new = !FileAccess::file_exists(&path);

        let project_settings = ProjectSettings::singleton();
        let full_path = project_settings.globalize_path(&path).to_string();

        let conn = Connection::open(&full_path).expect("failed to open database");
        self.connection = Some(conn);

        if is_new {
            self.initialize();
        }
    }

    #[func]
    pub fn is_empty(&self) -> bool {
        const QUERY_IS_EMPTY: &str = "SELECT NOT EXISTS (SELECT 1 FROM tb_level)";
        self.conn()
            .query_one(QUERY_IS_EMPTY, (), |row| row.get::<_, bool>(0))
            .unwrap()
    }

    /// Imports all level files from a directory.
    #[func]
    fn import_levels_from_dir(&self, path: String) {
        let path = path.trim_end_matches('/').to_string();

        let start = std::time::Instant::now();
        let directory = DirAccess::open(&path).expect("failed to open directory");
        for file_name in directory.get_files().as_slice() {
            if file_name.ends_with(".xsb") {
                self.import_levels_from_file(format!("{path}/{file_name}"));
            }
        }
        godot_print!("Levels imported from directory ({:?})", start.elapsed());
    }

    /// Imports levels from a file.
    #[func]
    fn import_levels_from_file(&self, path: String) {
        // Create a new Collection using the file stem as its name.
        let collection_name = std::path::Path::new(&path.to_string())
            .file_stem()
            .unwrap()
            .to_string_lossy()
            .to_string();

        let mut collection = orm::Collection {
            id: -1,
            name: collection_name.clone(),
            description: None,
        };
        collection.upsert();

        let file = FileAccess::open(&path, ModeFlags::READ).expect("failed to open file");
        self.insert_levels_from_str(&file.get_as_text().to_string(), &collection_name);
    }

    /// Imports levels from an XSB format string.
    #[func]
    fn import_levels_from_string(&self, xsb: String, collection_name: String) {
        self.insert_levels_from_str(&xsb, &collection_name);
    }

    #[func]
    pub fn get_collections(&self) -> Array<VarDictionary> {
        orm::Collection::query_all()
            .into_iter()
            .map(|collection| collection.into())
            .collect()
    }

    #[func]
    pub fn get_collection_size_by_name(&self, collection: GString) -> i64 {
        orm::Collection::query_by_name(&collection.to_string())
            .unwrap()
            .count()
    }

    #[func]
    pub fn get_level_index(&self, level_id: i64, collection_name: GString) -> i64 {
        let level = orm::Level::query_by_id(level_id).unwrap();
        let collection = orm::Collection::query_by_name(&collection_name.to_string()).unwrap();
        level.index_in_collection(&collection)
    }

    #[func]
    pub fn get_levels_by_collection_name(&self, collection: GString) -> Array<VarDictionary> {
        let collection = orm::Collection::query_by_name(&collection.to_string()).unwrap();
        let levels = collection.query_levels();
        levels.into_iter().map(|level| level.into()).collect()
    }

    #[func]
    pub fn get_level_by_id(&self, level_id: i64) -> VarDictionary {
        orm::Level::query_by_id(level_id).unwrap().into()
    }

    #[func]
    pub fn get_best_solution_by_level_id(&self, level_id: i64) -> VarDictionary {
        let level = orm::Level::query_by_id(level_id).unwrap();
        let mut dict = VarDictionary::new();
        dict.set(
            "move_optimal",
            level.move_optimal_lurd().unwrap_or_default(),
        );
        dict.set(
            "push_optimal",
            level.push_optimal_lurd().unwrap_or_default(),
        );
        dict
    }

    #[func]
    pub fn add_solution(&self, level_id: i64, actions_lurd: String) {
        let action = Actions::from_str(&actions_lurd).unwrap();

        let level = orm::Level::query_by_id(level_id).unwrap();
        let best_moves = level
            .move_optimal_lurd()
            .map(|lurd| Actions::from_str(&lurd).unwrap().moves());
        let best_pushes = level
            .push_optimal_lurd()
            .map(|lurd| Actions::from_str(&lurd).unwrap().pushes());
        let is_move_optimal = best_moves.is_none_or(|moves| action.moves() < moves);
        let is_push_optimal = best_pushes.is_none_or(|pushes| action.pushes() < pushes);

        Snapshot {
            level_id: level.id,
            actions_lurd,
            move_optimal: is_move_optimal,
            push_optimal: is_push_optimal,
        }
        .upsert();
    }

    fn insert_levels_from_str(&self, xsb: &str, collection_name: &str) {
        let collection = orm::Collection::query_by_name(collection_name).unwrap();

        self.conn().execute("BEGIN TRANSACTION", ()).unwrap();
        let levels = Level::load_from_str(xsb);
        for level in levels.map(Result::unwrap) {
            let mut orm_level = orm::Level::from(level);
            orm_level.upsert();
            collection.add_level(&orm_level);
        }
        self.conn().execute("COMMIT", ()).unwrap();
    }

    fn initialize(&mut self) {
        const CREATE_COLLECTION_TABLE: &str = "
            CREATE TABLE IF NOT EXISTS tb_collection (
                id          INTEGER PRIMARY KEY AUTOINCREMENT,
                name        TEXT NOT NULL UNIQUE,
                description TEXT,
                datetime    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
            );";
        const CREATE_LEVEL_TABLE: &str = "
            CREATE TABLE IF NOT EXISTS tb_level (
                id       INTEGER PRIMARY KEY AUTOINCREMENT,
                map_xsb  TEXT NOT NULL,
                title    TEXT,
                author   TEXT,
                comments TEXT,
                hash     INTEGER NOT NULL UNIQUE,
                datetime DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
            )";
        const CREATE_LEVEL_INDEX: &str =
            "CREATE UNIQUE INDEX IF NOT EXISTS ux_level_hash ON tb_level(hash)";
        const CREATE_COLLECTION_LEVEL_TABLE: &str = "
            CREATE TABLE IF NOT EXISTS tb_collection_level (
                collection_id INTEGER,
                level_id      INTEGER,
                PRIMARY KEY (collection_id, level_id),
                FOREIGN KEY (collection_id) REFERENCES tb_collection(id) ON DELETE CASCADE,
                FOREIGN KEY (level_id) REFERENCES tb_level(id) ON DELETE CASCADE
            )";
        const CREATE_SNAPSHOT_TABLE: &str = "
            CREATE TABLE IF NOT EXISTS tb_snapshot (
                level_id     INTEGER,
                actions_lurd TEXT,
                move_optimal BOOLEAN NOT NULL CHECK (move_optimal IN (0, 1)),
                push_optimal BOOLEAN NOT NULL CHECK (push_optimal IN (0, 1)),
                datetime     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                PRIMARY KEY (level_id, actions_lurd),
                FOREIGN KEY (level_id) REFERENCES tb_level(id) ON DELETE CASCADE
            )";

        self.conn().execute(CREATE_LEVEL_TABLE, ()).unwrap();
        self.conn().execute(CREATE_LEVEL_INDEX, ()).unwrap();
        self.conn().execute(CREATE_COLLECTION_TABLE, ()).unwrap();
        self.conn()
            .execute(CREATE_COLLECTION_LEVEL_TABLE, ())
            .unwrap();
        self.conn().execute(CREATE_SNAPSHOT_TABLE, ()).unwrap();
    }

    pub fn conn(&self) -> &Connection {
        self.connection.as_ref().expect("database not connected")
    }

    pub fn conn_mut(&mut self) -> &mut Connection {
        self.connection.as_mut().expect("database not connected")
    }
}
