// database/mod.rs - SQLite database para jogos
pub mod sqlite;

use std::path::Path;
use color_eyre::Result;
use async_trait::async_trait;
use serde::{Deserialize, Serialize};
use chrono::{DateTime, Utc};
use uuid::Uuid;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GameEntry {
    pub id: String,
    pub name: String,
    pub source: crate::sources::SourceType,
    pub cover: Option<std::path::PathBuf>,
    pub installed: bool,
    pub install_path: Option<std::path::PathBuf>,
    pub launch_cmd: Vec<String>,
    pub launch_env: Vec<(String, String)>,
    pub metadata: GameMetadata,
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct GameMetadata {
    pub hours_played: f32,
    pub last_played: Option<DateTime<Utc>>,
    pub rating: Option<u8>, // 0-10
    pub tags: Vec<String>,
    pub developers: Vec<String>,
    pub publishers: Vec<String>,
    pub release_date: Option<DateTime<Utc>>,
    pub description: Option<String>,
}

#[async_trait]
pub trait GameDatabase: Send + Sync {
    async fn init(&self) -> Result<()>;
    async fn migrate(&self) -> Result<()>;
    async fn upsert_game(&self, game: &GameEntry) -> Result<()>;
    async fn get_game(&self, id: &str) -> Result<Option<GameEntry>>;
    async fn get_all_games(&self) -> Result<Vec<GameEntry>>;
    async fn get_games_by_source(&self, source: crate::sources::SourceType) -> Result<Vec<GameEntry>>;
    async fn delete_game(&self, id: &str) -> Result<()>;
    async fn update_last_played(&self, id: &str) -> Result<()>;
    async fn update_playtime(&self, id: &str, hours: f32) -> Result<()>;
    async fn update_rating(&self, id: &str, rating: u8) -> Result<()>;
    async fn search_games(&self, query: &str) -> Result<Vec<GameEntry>>;
}

pub use sqlite::SqliteDatabase;

pub async fn open_database(path: &Path) -> Result<Box<dyn GameDatabase>> {
    let db = SqliteDatabase::new(path).await?;
    db.migrate().await?;
    Ok(Box::new(db))
}