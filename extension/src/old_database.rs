use std::{
    hash::{DefaultHasher, Hash, Hasher},
    io::{BufReader, Cursor},
    str::FromStr as _,
};

use godot::{
    classes::{DirAccess, FileAccess, ProjectSettings, file_access::ModeFlags},
    prelude::*,
};
use rusqlite::{Connection, Transaction};
use soukoban::{Actions, Level};

#[derive(GodotClass)]
#[class(init, singleton)]
pub struct OldDatabase {
    conn: Option<Connection>,
    base: Base<Object>,
}

#[godot_api]
impl OldDatabase {
    /// Load a SQLite database from a Godot path.
    /// If the file does not exist, an empty database is created and initialized from `res://assets/levels/`.
    #[func]
    pub fn load_from_file(&mut self, path: GString) {
        let is_new = !FileAccess::file_exists(&path);

        let project_settings = ProjectSettings::singleton();
        let full_path = project_settings.globalize_path(&path).to_string();

        let conn = Connection::open(&full_path).expect("failed to open database");
        self.conn = Some(conn);

        if is_new {
            let start = std::time::Instant::now();
            self.initialize();
            godot_print!("Database initialized ({:?})", start.elapsed());
        }
    }

    /// Returns all distinct collection names, sorted alphabetically.
    #[func]
    pub fn get_collections(&self) -> PackedStringArray {
        const QUERY_COLLECTIONS: &str = "SELECT name FROM tb_collection ORDER BY name";
        let mut stmt = self.conn().prepare(QUERY_COLLECTIONS).unwrap();
        let rows = stmt.query_map((), |row| row.get::<_, String>(0)).unwrap();
        PackedStringArray::from_iter(rows.map(|collection| GString::from(&collection.unwrap())))
    }

    /// Returns level metadata for every level in the collection, ordered by id.
    /// Each dict contains: "map", "title", "author", "comments", "completed" (bool).
    #[func]
    pub fn get_levels_in_collection(&self, collection: GString) -> Array<VarDictionary> {
        const QUERY_LEVELS_IN_COLLECTION: &str = "
            SELECT l.map_xsb, l.title, l.author, l.comments,
                EXISTS(SELECT 1 FROM tb_snapshot s
                        WHERE s.level_id = l.id AND s.push_optimal = 1) AS completed
            FROM tb_level l
            JOIN tb_collection_level cl ON l.id = cl.level_id
            JOIN tb_collection c ON cl.collection_id = c.id
            WHERE c.name = ?
            ORDER BY l.id";
        let mut stmt = self.conn().prepare(QUERY_LEVELS_IN_COLLECTION).unwrap();

        let rows = stmt
            .query_map((collection.to_string(),), |row| {
                Ok((
                    row.get::<_, String>(0)?,
                    row.get::<_, Option<String>>(1)?,
                    row.get::<_, Option<String>>(2)?,
                    row.get::<_, Option<String>>(3)?,
                    row.get::<_, bool>(4)?,
                ))
            })
            .unwrap();
        let mut levels = Array::new();
        for (map, title, author, comments, completed) in rows.map(Result::unwrap) {
            let mut dict = VarDictionary::new();
            dict.set("map", map);
            if let Some(value) = title {
                dict.set("title", value);
            }
            if let Some(value) = author {
                dict.set("author", value);
            }
            if let Some(value) = comments {
                dict.set("comments", value);
            }
            dict.set("completed", completed);
            levels.push(&dict);
        }
        levels
    }

    /// Returns level data (map and hash) for the nth level (0-indexed) in a collection.
    #[func]
    pub fn get_level(&self, collection: GString, index: i32) -> VarDictionary {
        const QUERY_LEVEL_IN_COLLECTION: &str = "
            SELECT l.map_xsb, l.hash FROM tb_level l
            JOIN tb_collection_level cl ON l.id = cl.level_id
            JOIN tb_collection c ON cl.collection_id = c.id
            WHERE c.name = ?
            ORDER BY l.id LIMIT 1 OFFSET ?";
        let result = self
            .conn()
            .query_row(
                QUERY_LEVEL_IN_COLLECTION,
                (collection.to_string(), index),
                |row| Ok((row.get::<_, String>(0)?, row.get::<_, i64>(1)?)),
            )
            .ok();

        let mut dict = VarDictionary::new();
        if let Some((map, hash)) = result {
            dict.set("map", map);
            dict.set("hash", hash);
        }
        dict
    }

    /// Returns `{"move_optimal": String, "push_optimal": String}` for the given level hash.
    /// Values are empty strings if no solution has been recorded yet.
    #[func]
    pub fn get_best_solution(&self, level_hash: i64) -> VarDictionary {
        let level_id = self.get_level_id_by_hash(level_hash);
        let (move_optimal_lurd, push_optimal_lurd) = self.query_optimal_solutions(level_id);

        let mut dict = VarDictionary::new();
        match (move_optimal_lurd, push_optimal_lurd) {
            (Some(move_lurd), Some(push_lurd)) => {
                dict.set("move_optimal", move_lurd);
                dict.set("push_optimal", push_lurd);
            }
            (None, None) => {
                dict.set("move_optimal", "");
                dict.set("push_optimal", "");
            }
            _ => unreachable!(),
        }

        dict
    }

    /// Saves a completed solution.
    #[func]
    pub fn save_solution(&mut self, level_hash: i64, actions_lurd: GString) {
        let level_id = self.get_level_id_by_hash(level_hash);
        let lurd = actions_lurd.to_string();
        let new_actions = Actions::from_str(&lurd).unwrap();

        let best_moves = self
            .conn()
            .query_row(
                "SELECT actions_lurd FROM tb_snapshot WHERE level_id = ? AND move_optimal = 1",
                (level_id,),
                |row| row.get::<_, String>(0),
            )
            .ok()
            .map(|lurd| Actions::from_str(&lurd).unwrap().moves());
        let best_pushes = self
            .conn()
            .query_row(
                "SELECT actions_lurd FROM tb_snapshot WHERE level_id = ? AND push_optimal = 1",
                (level_id,),
                |row| row.get::<_, String>(0),
            )
            .ok()
            .map(|lurd| Actions::from_str(&lurd).unwrap().pushes());
        let is_move_optimal = best_moves.is_none_or(|moves| new_actions.moves() < moves);
        let is_push_optimal = best_pushes.is_none_or(|pushes| new_actions.pushes() < pushes);

        let transaction = self
            .conn_mut()
            .transaction()
            .expect("failed to start transaction");
        if is_move_optimal {
            transaction
                .execute(
                    "UPDATE tb_snapshot SET move_optimal = 0 WHERE level_id = ?",
                    (level_id,),
                )
                .unwrap();
        }
        if is_push_optimal {
            transaction
                .execute(
                    "UPDATE tb_snapshot SET push_optimal = 0 WHERE level_id = ?",
                    (level_id,),
                )
                .unwrap();
        }
        transaction
                .execute("
                    INSERT OR REPLACE INTO tb_snapshot(level_id, actions_lurd, move_optimal, push_optimal)
                    VALUES (?, ?, ?, ?)",
                    (level_id, lurd.clone(), is_move_optimal, is_push_optimal),
                ).unwrap();
        transaction.commit().expect("failed to commit transaction");
    }

    fn get_level_id_by_hash(&self, hash: i64) -> i64 {
        self.conn()
            .query_row("SELECT id FROM tb_level WHERE hash = ?", (hash,), |row| {
                row.get::<_, i64>(0)
            })
            .unwrap()
    }

    fn initialize(&mut self) {
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
        const CREATE_COLLECTION_TABLE: &str = "
            CREATE TABLE IF NOT EXISTS tb_collection (
                id          INTEGER PRIMARY KEY AUTOINCREMENT,
                name        TEXT NOT NULL UNIQUE,
                description TEXT,
                datetime    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
            );";
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

        let transaction = self
            .conn_mut()
            .transaction()
            .expect("failed to start transaction");
        let directory = DirAccess::open("res://assets/levels/").unwrap();
        for file_name in directory.get_files().as_slice() {
            if file_name.ends_with(".xsb") {
                let path = format!("res://assets/levels/{file_name}");
                Self::import_levels_from_file((&path).into(), &transaction);
            }
        }
        transaction.commit().expect("failed to commit transaction");
    }

    fn import_levels_from_file(path: GString, transaction: &Transaction) {
        let path_str = path.to_string();
        let file_name = path_str.rsplit('/').next().unwrap_or(&path_str);
        let collection = file_name.trim_end_matches(".xsb");

        const INSERT_COLLECTION: &str = "INSERT OR IGNORE INTO tb_collection(name) VALUES (?)";
        transaction
            .execute(INSERT_COLLECTION, (collection,))
            .unwrap();

        const QUERY_COLLECTION_ID_BY_NAME: &str = "SELECT id FROM tb_collection WHERE name = ?";
        let collection_id: i64 = transaction
            .query_row(QUERY_COLLECTION_ID_BY_NAME, (collection,), |row| row.get(0))
            .unwrap();

        let mut file = FileAccess::open(&path, ModeFlags::READ).unwrap();
        let len = file.get_length() as i64;
        let buffer = file.get_buffer(len).to_vec();
        let reader = BufReader::new(Cursor::new(buffer));

        for level in Level::load_from_reader(reader).map(Result::unwrap) {
            Self::import_level(&level, collection_id, transaction);
        }
    }

    fn import_level(level: &Level, collection_id: i64, transaction: &Transaction) {
        let title = level.metadata().get("title");
        let author = level.metadata().get("author");
        let comments = level.metadata().get("comments");

        let mut map = level.map().clone();
        map.canonicalize();
        let mut hasher = DefaultHasher::new();
        map.hash(&mut hasher);
        let hash = hasher.finish() as i64;

        const INSERT_LEVEL: &str = "
            INSERT OR IGNORE INTO tb_level(map_xsb, title, author, comments, hash)
            VALUES (?, ?, ?, ?, ?)";
        transaction
            .execute(
                INSERT_LEVEL,
                (level.map().to_string(), title, author, comments, hash),
            )
            .expect("failed to insert level");

        const QUERY_LEVEL_ID_BY_HASH: &str = "SELECT id FROM tb_level WHERE hash = ?";
        let level_id: i64 = transaction
            .query_row(QUERY_LEVEL_ID_BY_HASH, (hash,), |row| row.get(0))
            .unwrap();

        transaction
            .execute(
                "INSERT OR IGNORE INTO tb_collection_level(collection_id, level_id)
                 VALUES (?, ?)",
                (collection_id, level_id),
            )
            .unwrap();
    }

    fn query_optimal_solutions(&self, level_id: i64) -> (Option<String>, Option<String>) {
        const QUERY_MOVE_OPTIMAL_ACTIONS_BY_LEVEL_ID: &str =
            "SELECT actions_lurd FROM tb_snapshot WHERE level_id = ? AND move_optimal = 1";
        let move_optimal_lurd = self
            .conn()
            .query_row(QUERY_MOVE_OPTIMAL_ACTIONS_BY_LEVEL_ID, (level_id,), |row| {
                row.get::<_, String>(0)
            })
            .ok();
        const QUERY_PUSH_OPTIMAL_ACTIONS_BY_LEVEL_ID: &str =
            "SELECT actions_lurd FROM tb_snapshot WHERE level_id = ? AND push_optimal = 1";
        let push_optimal_lurd = self
            .conn()
            .query_row(QUERY_PUSH_OPTIMAL_ACTIONS_BY_LEVEL_ID, (level_id,), |row| {
                row.get::<_, String>(0)
            })
            .ok();
        (move_optimal_lurd, push_optimal_lurd)
    }

    fn conn(&self) -> &Connection {
        self.conn.as_ref().expect("database not connected")
    }

    fn conn_mut(&mut self) -> &mut Connection {
        self.conn.as_mut().expect("database not connected")
    }
}
