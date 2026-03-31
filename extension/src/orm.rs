use std::hash::{DefaultHasher, Hash as _, Hasher as _};

use godot::prelude::*;

use crate::database::Database;

#[derive(Debug)]
pub struct Collection {
    pub id: i64,
    pub name: String,
    pub description: Option<String>,
}

impl Collection {
    pub fn query_all() -> Vec<Collection> {
        let singleton = Database::singleton();
        let db = singleton.bind();

        const QUERY_COLLECTIONS: &str =
            "SELECT id, name, description FROM tb_collection ORDER BY name";
        db.conn()
            .prepare(QUERY_COLLECTIONS)
            .unwrap()
            .query_map((), |row| {
                Ok(Collection {
                    id: row.get(0)?,
                    name: row.get(1)?,
                    description: row.get(2)?,
                })
            })
            .unwrap()
            .map(Result::unwrap)
            .collect()
    }

    pub fn query_by_name(name: &str) -> Option<Collection> {
        let singleton = Database::singleton();
        let db = singleton.bind();

        const QUERY_COLLECTION_BY_NAME: &str =
            "SELECT id, name, description FROM tb_collection WHERE name = ?";
        db.conn()
            .query_row(QUERY_COLLECTION_BY_NAME, (name,), |row| {
                Ok(Collection {
                    id: row.get(0)?,
                    name: row.get(1)?,
                    description: row.get(2)?,
                })
            })
            .ok()
    }

    pub fn count(&self) -> i64 {
        let singleton = Database::singleton();
        let db = singleton.bind();

        const COUNT_COLLECTION_LEVELS: &str =
            "SELECT COUNT(*) FROM tb_collection_level WHERE collection_id = ?";
        db.conn()
            .query_one(COUNT_COLLECTION_LEVELS, (self.id,), |row| row.get(0))
            .unwrap()
    }

    pub fn upsert(&mut self) {
        let singleton = Database::singleton();
        let db = singleton.bind();

        const UPSERT_COLLECTION: &str = "
            INSERT INTO tb_collection (name, description) VALUES (?, ?)
            ON CONFLICT(name) DO UPDATE SET description = excluded.description
            RETURNING id";
        self.id = db
            .conn()
            .query_row(UPSERT_COLLECTION, (&self.name, &self.description), |row| {
                row.get(0)
            })
            .unwrap();
    }

    pub fn query_levels(&self) -> Vec<Level> {
        let singleton = Database::singleton();
        let db = singleton.bind();

        const QUERY_LEVELS_BY_COLLECTION_ID: &str = "
            SELECT l.id, l.map_xsb, l.title, l.author, l.comments, l.hash
            FROM tb_level l
            JOIN tb_collection_level cl ON cl.level_id = l.id
            WHERE cl.collection_id = ?
            ORDER BY l.id";
        db.conn()
            .prepare(QUERY_LEVELS_BY_COLLECTION_ID)
            .unwrap()
            .query_map((self.id,), |row| {
                Ok(Level {
                    id: row.get(0)?,
                    map_xsb: row.get(1)?,
                    title: row.get(2)?,
                    author: row.get(3)?,
                    comments: row.get(4)?,
                    hash: row.get(5)?,
                })
            })
            .unwrap()
            .map(Result::unwrap)
            .collect()
    }

    pub fn add_level(&self, level: &Level) {
        assert!(level.id > 0);
        let singleton = Database::singleton();
        let db = singleton.bind();

        const ADD_LEVEL_TO_COLLECTION: &str =
            "INSERT OR IGNORE INTO tb_collection_level (collection_id, level_id) VALUES (?, ?)";
        db.conn()
            .execute(ADD_LEVEL_TO_COLLECTION, (self.id, level.id))
            .unwrap();
    }

    pub fn remove_level(&self, level: &Level) {
        let singleton = Database::singleton();
        let db = singleton.bind();

        const REMOVE_LEVELFROM_COLLECTION: &str =
            "DELETE FROM tb_collection_level WHERE collection_id = ? AND level_id = ?";
        db.conn()
            .execute(REMOVE_LEVELFROM_COLLECTION, (self.id, level.id))
            .unwrap();
    }
}

impl From<Collection> for VarDictionary {
    fn from(collection: Collection) -> Self {
        let mut dict = VarDictionary::new();
        dict.set("id", collection.id);
        dict.set("name", collection.name);
        if let Some(description) = collection.description {
            dict.set("description", description);
        }
        dict
    }
}

#[derive(Debug)]
pub struct Level {
    pub id: i64,
    pub map_xsb: String,
    pub title: Option<String>,
    pub author: Option<String>,
    pub comments: Option<String>,
    pub hash: i64,
}

impl Level {
    pub fn query_by_id(id: i64) -> Option<Level> {
        let singleton = Database::singleton();
        let db = singleton.bind();

        const QUERY_LEVEL_BY_ID: &str =
            "SELECT id, map_xsb, title, author, comments, hash FROM tb_level WHERE id = ?";
        db.conn()
            .query_row(QUERY_LEVEL_BY_ID, (id,), |row| {
                Ok(Level {
                    id: row.get(0)?,
                    map_xsb: row.get(1)?,
                    title: row.get(2)?,
                    author: row.get(3)?,
                    comments: row.get(4)?,
                    hash: row.get(5)?,
                })
            })
            .ok()
    }

    pub fn upsert(&mut self) {
        let singleton = Database::singleton();
        let db = singleton.bind();

        const UPSERT_LEVEL: &str = "
            INSERT INTO tb_level (map_xsb, title, author, comments, hash) VALUES (?, ?, ?, ?, ?)
            ON CONFLICT(hash) DO UPDATE SET
                title = COALESCE(title, excluded.title),
                author = COALESCE(author, excluded.author),
                comments = COALESCE(comments, excluded.comments)
            RETURNING id";
        self.id = db
            .conn()
            .query_row(
                UPSERT_LEVEL,
                (
                    &self.map_xsb,
                    &self.title,
                    &self.author,
                    &self.comments,
                    &self.hash,
                ),
                |row| row.get(0),
            )
            .unwrap();
    }

    pub fn index_in_collection(&self, collection: &Collection) -> i64 {
        let singleton = Database::singleton();
        let db = singleton.bind();

        const QUERY_LEVEL_INDEX_IN_COLLECTION: &str = "
            SELECT COUNT(*) - 1 FROM tb_collection_level
            WHERE collection_id = ? AND level_id <= ?";
        db.conn()
            .query_one(
                QUERY_LEVEL_INDEX_IN_COLLECTION,
                (collection.id, self.id),
                |row| row.get(0),
            )
            .unwrap()
    }

    pub fn move_optimal_lurd(&self) -> Option<String> {
        let singleton = Database::singleton();
        let db = singleton.bind();

        const QUERY_MOVE_OPTIMAL_SOLUTION_BY_LEVEL_ID: &str = "
            SELECT actions_lurd
            FROM tb_snapshot
            WHERE level_id = ? AND move_optimal = 1";
        db.conn()
            .query_row(QUERY_MOVE_OPTIMAL_SOLUTION_BY_LEVEL_ID, (self.id,), |row| {
                row.get(0)
            })
            .ok()
    }

    pub fn push_optimal_lurd(&self) -> Option<String> {
        let singleton = Database::singleton();
        let db = singleton.bind();

        const QUERY_PUSH_OPTIMAL_SOLUTION_BY_LEVEL_ID: &str = "
            SELECT actions_lurd
            FROM tb_snapshot
            WHERE level_id = ? AND push_optimal = 1";
        db.conn()
            .query_row(QUERY_PUSH_OPTIMAL_SOLUTION_BY_LEVEL_ID, (self.id,), |row| {
                row.get(0)
            })
            .ok()
    }

    pub fn best_solution(&self) -> Option<Snapshot> {
        let singleton = Database::singleton();
        let db = singleton.bind();

        const QUERY_BEST_SOLUTION_BY_LEVEL_ID: &str = "
            SELECT actions_lurd, move_optimal, push_optimal
            FROM tb_snapshot
            WHERE level_id = ?
            ORDER BY move_optimal DESC, push_optimal DESC, datetime ASC
            LIMIT 1";
        db.conn()
            .query_row(QUERY_BEST_SOLUTION_BY_LEVEL_ID, (self.id,), |row| {
                Ok(Snapshot {
                    level_id: self.id,
                    actions_lurd: row.get(0)?,
                    move_optimal: row.get(1)?,
                    push_optimal: row.get(2)?,
                })
            })
            .ok()
    }

    pub fn completed(&self) -> bool {
        self.best_solution().is_some()
    }
}

impl From<Level> for VarDictionary {
    fn from(level: Level) -> Self {
        let mut dict = VarDictionary::new();
        dict.set("id", level.id);
        dict.set("completed", level.completed());
        dict.set("map_xsb", level.map_xsb);
        if let Some(title) = level.title {
            dict.set("title", title);
        }
        if let Some(author) = level.author {
            dict.set("author", author);
        }
        if let Some(comments) = level.comments {
            dict.set("comments", comments);
        }
        dict.set("hash", level.hash);
        dict
    }
}

impl From<soukoban::Level> for Level {
    fn from(level: soukoban::Level) -> Self {
        let title = level.metadata().get("title");
        let author = level.metadata().get("author");
        let comments = level.metadata().get("comments");

        let mut map = level.map().clone();
        map.canonicalize();
        let mut hasher = DefaultHasher::new();
        map.hash(&mut hasher);
        let hash = hasher.finish() as i64;

        Self {
            id: -1,
            map_xsb: level.map().to_string(),
            title: title.cloned(),
            author: author.cloned(),
            comments: comments.cloned(),
            hash,
        }
    }
}

#[derive(Debug)]
pub struct Snapshot {
    pub level_id: i64,
    pub actions_lurd: String,
    pub move_optimal: bool,
    pub push_optimal: bool,
}

impl Snapshot {
    pub fn upsert(&self) {
        let singleton = Database::singleton();
        let db = singleton.bind();

        const UPSERT_SOLUTION: &str = "
            INSERT INTO tb_snapshot (level_id, actions_lurd, move_optimal, push_optimal)
            VALUES (?, ?, ?, ?)
            ON CONFLICT(level_id, actions_lurd) DO UPDATE SET
                move_optimal = excluded.move_optimal,
                push_optimal = excluded.push_optimal";
        db.conn()
            .execute(
                UPSERT_SOLUTION,
                (
                    self.level_id,
                    &self.actions_lurd,
                    self.move_optimal,
                    self.push_optimal,
                ),
            )
            .unwrap();
    }
}

impl From<Snapshot> for VarDictionary {
    fn from(snapshot: Snapshot) -> Self {
        let mut dict = VarDictionary::new();
        dict.set("actions_lurd", snapshot.actions_lurd);
        dict.set("move_optimal", snapshot.move_optimal);
        dict.set("push_optimal", snapshot.push_optimal);
        dict
    }
}
