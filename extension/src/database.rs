use std::hash::{DefaultHasher, Hash as _, Hasher as _};
use std::str::FromStr as _;

use godot::{
    classes::{DirAccess, FileAccess, ProjectSettings, file_access::ModeFlags},
    prelude::*,
};
use rusqlite::Connection;
use soukoban::{Actions, Level};

#[derive(GodotClass)]
#[class(init, singleton)]
pub struct Database {
    connection: Option<Connection>,
}

#[godot_api]
impl Database {
    /// Opens a connection to the SQLite database.
    /// Creates the database and its schema if it does not exist.
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

    /// Checks whether the level table is currently empty.
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
        let collection_name = std::path::Path::new(&path)
            .file_stem()
            .unwrap()
            .to_string_lossy()
            .to_string();

        let file = FileAccess::open(&path, ModeFlags::READ).expect("failed to open file");
        self.insert_levels_from_str(&file.get_as_text().to_string(), &collection_name);
    }

    /// Imports levels from an XSB format string.
    #[func]
    fn import_levels_from_string(&self, levels_xsb: String, collection_name: String) {
        self.insert_levels_from_str(&levels_xsb, &collection_name);
    }

    /// Retrieves an array of all imported level collections.
    #[func]
    pub fn get_collections(&self) -> Array<VarDictionary> {
        const QUERY_COLLECTIONS: &str =
            "SELECT id, name, description FROM tb_collection ORDER BY name";
        self.conn()
            .prepare(QUERY_COLLECTIONS)
            .unwrap()
            .query_map((), |row| {
                let mut dict = VarDictionary::new();
                dict.set("id", row.get::<_, i64>(0)?);
                dict.set("name", row.get::<_, String>(1)?);
                if let Ok(Some(desc)) = row.get::<_, Option<String>>(2) {
                    dict.set("description", desc);
                }
                Ok(dict)
            })
            .unwrap()
            .map(Result::unwrap)
            .collect()
    }

    /// Returns the total number of levels within a specified collection.
    #[func]
    pub fn get_collection_size(&self, collection_name: String) -> i64 {
        const COUNT_LEVELS: &str = "
            SELECT COUNT(*) FROM tb_collection_level cl
            JOIN tb_collection c ON c.id = cl.collection_id
            WHERE c.name = ?";
        self.conn()
            .query_row(COUNT_LEVELS, (collection_name,), |row| row.get(0))
            .unwrap()
    }

    /// Determines the 0-based sequence index of a specific level within its collection.
    #[func]
    pub fn get_level_index(&self, level_id: i64, collection_name: String) -> i64 {
        const QUERY_LEVEL_INDEX: &str = "
            SELECT COUNT(*) - 1 FROM tb_collection_level cl
            JOIN tb_collection c ON c.id = cl.collection_id
            WHERE c.name = ? AND cl.level_id <= ?";
        self.conn()
            .query_row(QUERY_LEVEL_INDEX, (collection_name, level_id), |row| {
                row.get(0)
            })
            .unwrap()
    }

    /// Extracts all level details belonging to a given collection natively.
    #[func]
    pub fn get_collection_levels(&self, collection_name: String) -> Array<VarDictionary> {
        const QUERY_LEVELS: &str = "
            SELECT l.id, l.map_xsb, l.title, l.author, l.comments, l.hash,
                   EXISTS(SELECT 1 FROM tb_solution s WHERE s.level_id = l.id) as solved,
                   EXISTS(SELECT 1 FROM tb_snapshot s WHERE s.level_id = l.id AND s.autosave = 1) as solving
            FROM tb_level l
            JOIN tb_collection_level cl ON cl.level_id = l.id
            JOIN tb_collection c ON c.id = cl.collection_id
            WHERE c.name = ?
            ORDER BY l.id";
        self.conn()
            .prepare(QUERY_LEVELS)
            .unwrap()
            .query_map((collection_name,), |row| {
                let mut dict = Self::map_level_row(row)?;
                dict.set("solved", row.get::<_, bool>(6)?);
                dict.set("solving", row.get::<_, bool>(7)?);
                Ok(dict)
            })
            .unwrap()
            .map(Result::unwrap)
            .collect()
    }

    /// Queries exactly one level from the database and maps it into a Godot dictionary.
    #[func]
    pub fn get_level(&self, level_id: i64) -> VarDictionary {
        const QUERY_BY_ID: &str =
            "SELECT id, map_xsb, title, author, comments, hash FROM tb_level WHERE id = ?";
        self.conn()
            .query_row(QUERY_BY_ID, (level_id,), Self::map_level_row)
            .unwrap()
    }

    /// Returns the currently discovered minimum moves or pushes strategy to beat the level.
    #[func]
    pub fn get_best_solution(&self, level_id: i64) -> VarDictionary {
        let optimal_move_lurd = self.query_move_optimal_lurd(level_id).unwrap_or_default();
        let optimal_push_lurd = self.query_push_optimal_lurd(level_id).unwrap_or_default();

        let mut dict = VarDictionary::new();
        dict.set("push_optimal", optimal_push_lurd);
        dict.set("move_optimal", optimal_move_lurd);
        dict
    }

    /// Submits a new solution to the database.
    #[func]
    pub fn add_solution(&self, level_id: i64, actions_lurd: String) {
        let action = Actions::from_str(&actions_lurd).unwrap();

        let best_move_count = self
            .query_move_optimal_lurd(level_id)
            .map(|l| Actions::from_str(&l).unwrap().moves());

        let best_push_count = self
            .query_push_optimal_lurd(level_id)
            .map(|l| Actions::from_str(&l).unwrap().pushes());

        let is_move_optimal = best_move_count.is_none_or(|moves| action.moves() < moves);
        let is_push_optimal = best_push_count.is_none_or(|pushes| action.pushes() < pushes);

        let tx = self.conn().unchecked_transaction().unwrap();

        if is_move_optimal {
            let _ = tx.execute(
                "UPDATE tb_solution SET move_optimal = 0 WHERE level_id = ?",
                (level_id,),
            );
        }
        if is_push_optimal {
            let _ = tx.execute(
                "UPDATE tb_solution SET push_optimal = 0 WHERE level_id = ?",
                (level_id,),
            );
        }

        const UPSERT_SOLUTION: &str = "
            INSERT OR IGNORE INTO tb_solution (level_id, actions_lurd, move_optimal, push_optimal) VALUES (?, ?, ?, ?)";
        tx.execute(
            UPSERT_SOLUTION,
            (level_id, actions_lurd, is_move_optimal, is_push_optimal),
        )
        .unwrap();
        tx.commit().unwrap();
    }

    #[func]
    pub fn save_snapshot(&self, level_id: i64, actions_lurd: String, autosave: bool) {
        if actions_lurd.is_empty() {
            return;
        }

        let tx = self.conn().unchecked_transaction().unwrap();
        if autosave {
            let _ = tx.execute(
                "DELETE FROM tb_snapshot WHERE level_id = ? AND autosave = 1",
                (level_id,),
            );
        }
        let _ = tx.execute(
            "INSERT INTO tb_snapshot (level_id, actions_lurd, autosave) VALUES (?, ?, ?)",
            (level_id, actions_lurd, autosave),
        );
        tx.commit().unwrap();
    }

    #[func]
    pub fn get_snapshot(&self, level_id: i64, autosave: bool) -> String {
        const QUERY_SNAPSHOT: &str = "SELECT actions_lurd FROM tb_snapshot WHERE level_id = ? AND autosave = ? ORDER BY datetime DESC LIMIT 1";
        self.conn()
            .query_row(QUERY_SNAPSHOT, (level_id, autosave), |row| {
                row.get::<_, String>(0)
            })
            .unwrap_or_default()
    }

    #[func]
    pub fn clear_snapshot(&self, level_id: i64, autosave: bool) {
        let _ = self.conn().execute(
            "DELETE FROM tb_snapshot WHERE level_id = ? AND autosave = ?",
            (level_id, autosave),
        );
    }

    fn insert_levels_from_str(&self, levels_xsb: &str, collection_name: &str) {
        let tx = self.conn().unchecked_transaction().unwrap();

        const UPSERT_COLLECTION: &str = "
            INSERT INTO tb_collection (name) VALUES (?1)
            ON CONFLICT(name) DO UPDATE SET name = excluded.name
            RETURNING id";
        let collection_id: i64 = tx
            .query_row(UPSERT_COLLECTION, (collection_name,), |row| row.get(0))
            .unwrap();

        let levels = Level::load_from_str(levels_xsb);
        for level in levels.map(Result::unwrap) {
            let title = level.metadata().get("title").cloned();
            let author = level.metadata().get("author").cloned();
            let comments = level.metadata().get("comments").cloned();

            let mut map = level.map().clone();
            map.canonicalize();
            let mut hasher = DefaultHasher::new();
            map.hash(&mut hasher);
            let hash = hasher.finish() as i64;

            let map_xsb = level.map().to_string();

            const UPSERT_LEVEL: &str = "
                INSERT INTO tb_level (map_xsb, title, author, comments, hash) VALUES (?1, ?2, ?3, ?4, ?5)
                ON CONFLICT(hash) DO UPDATE SET
                    title = COALESCE(title, excluded.title),
                    author = COALESCE(author, excluded.author),
                    comments = COALESCE(comments, excluded.comments)
                RETURNING id";
            let level_id: i64 = tx
                .query_row(
                    UPSERT_LEVEL,
                    (map_xsb, title, author, comments, hash),
                    |row| row.get(0),
                )
                .unwrap();

            const ADD_LEVEL_TO_COLLECTION: &str = "INSERT OR IGNORE INTO tb_collection_level (collection_id, level_id) VALUES (?1, ?2)";
            tx.execute(ADD_LEVEL_TO_COLLECTION, (collection_id, level_id))
                .unwrap();
        }
        tx.commit().unwrap();
    }

    fn query_move_optimal_lurd(&self, level_id: i64) -> Option<String> {
        const QUERY_MOVE_OPTIMAL: &str =
            "SELECT actions_lurd FROM tb_solution WHERE level_id = ? AND move_optimal = 1";
        self.conn()
            .query_row(QUERY_MOVE_OPTIMAL, (level_id,), |row| {
                row.get::<_, String>(0)
            })
            .ok()
    }

    fn query_push_optimal_lurd(&self, level_id: i64) -> Option<String> {
        const QUERY_PUSH_OPTIMAL: &str =
            "SELECT actions_lurd FROM tb_solution WHERE level_id = ? AND push_optimal = 1";
        self.conn()
            .query_row(QUERY_PUSH_OPTIMAL, (level_id,), |row| {
                row.get::<_, String>(0)
            })
            .ok()
    }

    fn map_level_row(row: &rusqlite::Row) -> rusqlite::Result<VarDictionary> {
        let mut dict = VarDictionary::new();
        dict.set("id", row.get::<_, i64>(0)?);
        dict.set("map_xsb", row.get::<_, String>(1)?);
        if let Ok(Some(title)) = row.get::<_, Option<String>>(2) {
            dict.set("title", title);
        }
        if let Ok(Some(author)) = row.get::<_, Option<String>>(3) {
            dict.set("author", author);
        }
        if let Ok(Some(comments)) = row.get::<_, Option<String>>(4) {
            dict.set("comments", comments);
        }
        dict.set("hash", row.get::<_, i64>(5)?);
        Ok(dict)
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
            );";
        const CREATE_LEVEL_INDEX: &str =
            "CREATE UNIQUE INDEX IF NOT EXISTS ux_level_hash ON tb_level(hash);";
        const CREATE_COLLECTION_LEVEL_TABLE: &str = "
            CREATE TABLE IF NOT EXISTS tb_collection_level (
                collection_id INTEGER,
                level_id      INTEGER,
                PRIMARY KEY (collection_id, level_id),
                FOREIGN KEY (collection_id) REFERENCES tb_collection(id) ON DELETE CASCADE,
                FOREIGN KEY (level_id) REFERENCES tb_level(id) ON DELETE CASCADE
            );";
        const CREATE_SOLUTION_TABLE: &str = "
            CREATE TABLE IF NOT EXISTS tb_solution (
                level_id     INTEGER,
                actions_lurd TEXT,
                move_optimal BOOLEAN NOT NULL,
                push_optimal BOOLEAN NOT NULL,
                datetime     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                PRIMARY KEY (level_id, actions_lurd),
                FOREIGN KEY (level_id) REFERENCES tb_level(id) ON DELETE CASCADE
            );";
        const CREATE_SNAPSHOT_TABLE: &str = "
            CREATE TABLE IF NOT EXISTS tb_snapshot (
                id           INTEGER PRIMARY KEY AUTOINCREMENT,
                level_id     INTEGER,
                actions_lurd TEXT,
                autosave     BOOLEAN NOT NULL,
                datetime     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (level_id) REFERENCES tb_level(id) ON DELETE CASCADE
            );";

        self.conn().execute(CREATE_LEVEL_TABLE, ()).unwrap();
        self.conn().execute(CREATE_LEVEL_INDEX, ()).unwrap();
        self.conn().execute(CREATE_COLLECTION_TABLE, ()).unwrap();
        self.conn()
            .execute(CREATE_COLLECTION_LEVEL_TABLE, ())
            .unwrap();
        self.conn().execute(CREATE_SOLUTION_TABLE, ()).unwrap();
        self.conn().execute(CREATE_SNAPSHOT_TABLE, ()).unwrap();
    }

    pub fn conn(&self) -> &Connection {
        self.connection.as_ref().expect("database not connected")
    }
}
