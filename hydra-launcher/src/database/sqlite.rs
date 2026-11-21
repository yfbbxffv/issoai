// database/sqlite.rs - Implementação SQLite com sqlx
use std::path::Path;
use color_eyre::Result;
use sqlx::{sqlite::SqlitePoolOptions, Row, SqlitePool};
use tracing::{info, debug};
use chrono::Utc;
use uuid::Uuid;

use crate::database::{GameDatabase, GameEntry, GameMetadata};
use crate::sources::SourceType;

pub struct SqliteDatabase {
    pool: SqlitePool,
}

impl SqliteDatabase {
    pub async fn new(path: &Path) -> Result<Self> {
        // Cria diretório se não existe
        if let Some(parent) = path.parent() {
            tokio::fs::create_dir_all(parent).await?;
        }

        let db_url = format!("sqlite://{}?mode=rwc", path.display());
        let pool = SqlitePoolOptions::new()
            .max_connections(5)
            .connect(&db_url)
            .await?;

        info!("Database opened: {}", path.display());
        Ok(Self { pool })
    }
}

impl SqliteDatabase {
    async fn create_tables(&self) -> Result<()> {
        sqlx::query(
            r#"
            CREATE TABLE IF NOT EXISTS games (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                source TEXT NOT NULL,
                cover_path TEXT,
                installed INTEGER NOT NULL DEFAULT 1,
                install_path TEXT,
                launch_cmd TEXT NOT NULL, -- JSON array
                launch_env TEXT NOT NULL, -- JSON array of pairs
                hours_played REAL NOT NULL DEFAULT 0.0,
                last_played TEXT,
                rating INTEGER,
                tags TEXT NOT NULL DEFAULT '[]', -- JSON array
                developers TEXT NOT NULL DEFAULT '[]', -- JSON array
                publishers TEXT NOT NULL DEFAULT '[]', -- JSON array
                release_date TEXT,
                description TEXT,
                created_at TEXT NOT NULL DEFAULT (datetime('now')),
                updated_at TEXT NOT NULL DEFAULT (datetime('now'))
            );
            "#
        ).execute(&self.pool).await?;

        // Índices
        sqlx::query("CREATE INDEX IF NOT EXISTS idx_games_source ON games(source);").execute(&self.pool).await?;
        sqlx::query("CREATE INDEX IF NOT EXISTS idx_games_name ON games(name);").execute(&self.pool).await?;
        sqlx::query("CREATE INDEX IF NOT EXISTS idx_games_installed ON games(installed);").execute(&self.pool).await?;
        sqlx::query("CREATE INDEX IF NOT EXISTS idx_games_last_played ON games(last_played);").execute(&self.pool).await?;

        // Tabela de instalações em andamento
        sqlx::query(
            r#"
            CREATE TABLE IF NOT EXISTS installs (
                id TEXT PRIMARY KEY,
                game_id TEXT NOT NULL,
                source TEXT NOT NULL,
                status TEXT NOT NULL, -- 'downloading', 'installing', 'completed', 'failed'
                progress REAL NOT NULL DEFAULT 0.0,
                total_bytes INTEGER NOT NULL DEFAULT 0,
                downloaded_bytes INTEGER NOT NULL DEFAULT 0,
                error_message TEXT,
                started_at TEXT NOT NULL DEFAULT (datetime('now')),
                completed_at TEXT,
                FOREIGN KEY(game_id) REFERENCES games(id)
            );
            "#
        ).execute(&self.pool).await?;

        Ok(())
    }

    fn row_to_game_entry(&self, row: &sqlx::sqlite::SqliteRow) -> Result<GameEntry> {
        let launch_cmd: String = row.try_get("launch_cmd")?;
        let launch_env: String = row.try_get("launch_env")?;
        let tags: String = row.try_get("tags")?;
        let developers: String = row.try_get("developers")?;
        let publishers: String = row.try_get("publishers")?;

        Ok(GameEntry {
            id: row.try_get("id")?,
            name: row.try_get("name")?,
            source: match row.try_get::<String, _>("source")?.as_str() {
                "Steam" => SourceType::Steam,
                "Lutris" => SourceType::Lutris,
                "Heroic" => SourceType::Heroic,
                "Ryujinx" => SourceType::Ryujinx,
                "Yuzu" => SourceType::Yuzu,
                "RetroArch" => SourceType::RetroArch,
                "Manual" => SourceType::Manual,
                _ => SourceType::Manual,
            },
            cover: row.try_get::<Option<String>, _>("cover_path")?.map(PathBuf::from),
            installed: row.try_get::<i64, _>("installed")? == 1,
            install_path: row.try_get::<Option<String>, _>("install_path")?.map(PathBuf::from),
            launch_cmd: serde_json::from_str(&launch_cmd)?,
            launch_env: serde_json::from_str(&launch_env)?,
            metadata: GameMetadata {
                hours_played: row.try_get("hours_played")?,
                last_played: row.try_get::<Option<String>, _>("last_played")?
                    .and_then(|s| chrono::DateTime::parse_from_rfc3339(&s).ok())
                    .map(|dt| dt.with_timezone(&Utc)),
                rating: row.try_get("rating")?,
                tags: serde_json::from_str(&tags)?,
                developers: serde_json::from_str(&developers)?,
                publishers: serde_json::from_str(&publishers)?,
                release_date: row.try_get::<Option<String>, _>("release_date")?
                    .and_then(|s| chrono::DateTime::parse_from_rfc3339(&s).ok())
                    .map(|dt| dt.with_timezone(&Utc)),
                description: row.try_get("description")?,
            },
        })
    }
}

#[async_trait::async_trait]
impl GameDatabase for SqliteDatabase {
    async fn init(&self) -> Result<()> {
        self.create_tables().await
    }

    async fn migrate(&self) -> Result<()> {
        // Migrações futuras virão aqui
        self.create_tables().await
    }

    async fn upsert_game(&self, game: &GameEntry) -> Result<()> {
        let launch_cmd = serde_json::to_string(&game.launch_cmd)?;
        let launch_env = serde_json::to_string(&game.launch_env)?;
        let tags = serde_json::to_string(&game.metadata.tags)?;
        let developers = serde_json::to_string(&game.metadata.developers)?;
        let publishers = serde_json::to_string(&game.metadata.publishers)?;

        sqlx::query(
            r#"
            INSERT INTO games (id, name, source, cover_path, installed, install_path, launch_cmd, launch_env,
                               hours_played, last_played, rating, tags, developers, publishers, release_date, description, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, datetime('now'))
            ON CONFLICT(id) DO UPDATE SET
                name = excluded.name,
                source = excluded.source,
                cover_path = excluded.cover_path,
                installed = excluded.installed,
                install_path = excluded.install_path,
                launch_cmd = excluded.launch_cmd,
                launch_env = excluded.launch_env,
                hours_played = excluded.hours_played,
                last_played = excluded.last_played,
                rating = excluded.rating,
                tags = excluded.tags,
                developers = excluded.developers,
                publishers = excluded.publishers,
                release_date = excluded.release_date,
                description = excluded.description,
                updated_at = datetime('now');
            "#
        )
        .bind(&game.id)
        .bind(&game.name)
        .bind(format!("{:?}", game.source))
        .bind(game.cover.as_ref().map(|p| p.to_string_lossy().to_string()))
        .bind(if game.installed { 1 } else { 0 })
        .bind(game.install_path.as_ref().map(|p| p.to_string_lossy().to_string()))
        .bind(&launch_cmd)
        .bind(&launch_env)
        .bind(game.metadata.hours_played)
        .bind(game.metadata.last_played.map(|dt| dt.to_rfc3339()))
        .bind(game.metadata.rating.map(|r| r as i64))
        .bind(&tags)
        .bind(&developers)
        .bind(&publishers)
        .bind(game.metadata.release_date.map(|dt| dt.to_rfc3339()))
        .bind(&game.metadata.description)
        .execute(&self.pool)
        .await?;

        debug!("Upserted game: {}", game.id);
        Ok(())
    }

    async fn get_game(&self, id: &str) -> Result<Option<GameEntry>> {
        let row = sqlx::query("SELECT * FROM games WHERE id = ?")
            .bind(id)
            .fetch_optional(&self.pool)
            .await?;

        Ok(row.map(|r| self.row_to_game_entry(&r)).transpose()?)
    }

    async fn get_all_games(&self) -> Result<Vec<GameEntry>> {
        let rows = sqlx::query("SELECT * FROM games ORDER BY last_played DESC NULLS LAST, name ASC")
            .fetch_all(&self.pool)
            .await?;

        rows.into_iter().map(|r| self.row_to_game_entry(&r)).collect()
    }

    async fn get_games_by_source(&self, source: SourceType) -> Result<Vec<GameEntry>> {
        let rows = sqlx::query("SELECT * FROM games WHERE source = ? ORDER BY name ASC")
            .bind(format!("{:?}", source))
            .fetch_all(&self.pool)
            .await?;

        rows.into_iter().map(|r| self.row_to_game_entry(&r)).collect()
    }

    async fn delete_game(&self, id: &str) -> Result<()> {
        sqlx::query("DELETE FROM games WHERE id = ?")
            .bind(id)
            .execute(&self.pool)
            .await?;
        Ok(())
    }

    async fn update_last_played(&self, id: &str) -> Result<()> {
        sqlx::query("UPDATE games SET last_played = datetime('now'), updated_at = datetime('now') WHERE id = ?")
            .bind(id)
            .execute(&self.pool)
            .await?;
        Ok(())
    }

    async fn update_playtime(&self, id: &str, hours: f32) -> Result<()> {
        sqlx::query("UPDATE games SET hours_played = hours_played + ?, updated_at = datetime('now') WHERE id = ?")
            .bind(hours as f64)
            .bind(id)
            .execute(&self.pool)
            .await?;
        Ok(())
    }

    async fn update_rating(&self, id: &str, rating: u8) -> Result<()> {
        sqlx::query("UPDATE games SET rating = ?, updated_at = datetime('now') WHERE id = ?")
            .bind(rating as i64)
            .bind(id)
            .execute(&self.pool)
            .await?;
        Ok(())
    }

    async fn search_games(&self, query: &str) -> Result<Vec<GameEntry>> {
        let like_query = format!("%{}%", query.to_lowercase());
        let rows = sqlx::query("SELECT * FROM games WHERE LOWER(name) LIKE ? ORDER BY name ASC")
            .bind(&like_query)
            .fetch_all(&self.pool)
            .await?;

        rows.into_iter().map(|r| self.row_to_game_entry(&r)).collect()
    }
}

// Install tracking
impl SqliteDatabase {
    pub async fn create_install(&self, install: &crate::install::InstallRecord) -> Result<()> {
        sqlx::query(
            r#"
            INSERT INTO installs (id, game_id, source, status, progress, total_bytes, downloaded_bytes, started_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, datetime('now'))
            "#
        )
        .bind(&install.id)
        .bind(&install.game_id)
        .bind(&install.source)
        .bind(&install.status)
        .bind(install.progress)
        .bind(install.total_bytes as i64)
        .bind(install.downloaded_bytes as i64)
        .execute(&self.pool)
        .await?;
        Ok(())
    }

    pub async fn update_install_progress(&self, id: &str, progress: f32, downloaded: u64, status: &str) -> Result<()> {
        sqlx::query(
            r#"
            UPDATE installs SET progress = ?, downloaded_bytes = ?, status = ?
            WHERE id = ?
            "#
        )
        .bind(progress as f64)
        .bind(downloaded as i64)
        .bind(status)
        .bind(id)
        .execute(&self.pool)
        .await?;
        Ok(())
    }

    pub async fn complete_install(&self, id: &str, success: bool, error: Option<String>) -> Result<()> {
        sqlx::query(
            r#"
            UPDATE installs SET status = ?, progress = 1.0, completed_at = datetime('now'), error_message = ?
            WHERE id = ?
            "#
        )
        .bind(if success { "completed" } else { "failed" })
        .bind(error)
        .bind(id)
        .execute(&self.pool)
        .await?;
        Ok(())
    }
}

use std::path::PathBuf;