// install/mod.rs - Pipeline de instalação de jogos
pub mod pipeline;

use std::path::PathBuf;
use color_eyre::Result;
use serde::{Deserialize, Serialize};
use uuid::Uuid;
use chrono::{DateTime, Utc};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct InstallRecord {
    pub id: String,
    pub game_id: String,
    pub source: String,
    pub status: InstallStatus,
    pub progress: f32,
    pub total_bytes: u64,
    pub downloaded_bytes: u64,
    pub error_message: Option<String>,
    pub started_at: DateTime<Utc>,
    pub completed_at: Option<DateTime<Utc>>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "lowercase")]
pub enum InstallStatus {
    Queued,
    Downloading,
    Verifying,
    Installing,
    Configuring,
    ShaderCaching,
    Completed,
    Failed,
    Cancelled,
}

#[derive(Debug, Clone)]
pub struct InstallProgress {
    pub status: InstallStatus,
    pub progress: f32, // 0.0 - 1.0
    pub downloaded_bytes: u64,
    pub total_bytes: u64,
    pub speed_bytes_per_sec: u64,
    pub eta_seconds: Option<u64>,
    pub current_file: Option<String>,
    pub message: Option<String>,
}

pub type ProgressCallback = Box<dyn Fn(InstallProgress) + Send + Sync>;

#[derive(Debug, Clone)]
pub struct InstallConfig {
    pub games_path: PathBuf,
    pub temp_path: PathBuf,
    pub cache_path: PathBuf,
    pub max_parallel_downloads: usize,
    pub verify_checksums: bool,
    pub precompile_shaders: bool,
}

impl Default for InstallConfig {
    fn default() -> Self {
        Self {
            games_path: PathBuf::from("/games/1"),
            temp_path: PathBuf::from("/tmp/hydra-installs"),
            cache_path: PathBuf::from("/home/gamer/.cache/hydra/downloads"),
            max_parallel_downloads: 4,
            verify_checksums: true,
            precompile_shaders: true,
        }
    }
}

pub struct InstallManager {
    config: InstallConfig,
    database: std::sync::Arc<crate::database::SqliteDatabase>,
}

impl InstallManager {
    pub async fn new(config: crate::app::Config, database: std::sync::Arc<crate::database::SqliteDatabase>) -> Result<Self> {
        let install_config = InstallConfig {
            games_path: config.games_paths.first().cloned().unwrap_or_else(|| PathBuf::from("/games/1")),
            temp_path: PathBuf::from("/tmp/hydra-installs"),
            cache_path: config.cache_dir.join("downloads"),
            max_parallel_downloads: 4,
            verify_checksums: true,
            precompile_shaders: true,
        };

        tokio::fs::create_dir_all(&install_config.temp_path).await?;
        tokio::fs::create_dir_all(&install_config.cache_path).await?;

        Ok(Self { config: install_config, database })
    }

    pub async fn install(&self, source: crate::sources::SourceType, game_id: &str, database: std::sync::Arc<crate::database::SqliteDatabase>) -> Result<()> {
        let install_id = Uuid::new_v4().to_string();

        // Cria registro de instalação
        let record = InstallRecord {
            id: install_id.clone(),
            game_id: game_id.to_string(),
            source: format!("{:?}", source),
            status: InstallStatus::Queued,
            progress: 0.0,
            total_bytes: 0,
            downloaded_bytes: 0,
            error_message: None,
            started_at: Utc::now(),
            completed_at: None,
        };

        self.database.create_install(&record).await?;

        // Executa pipeline baseado na fonte
        let result = match source {
            crate::sources::SourceType::Steam => self.install_steam(&install_id, game_id).await,
            crate::sources::SourceType::Heroic => self.install_heroic(&install_id, game_id).await,
            crate::sources::SourceType::Lutris => self.install_lutris(&install_id, game_id).await,
            crate::sources::SourceType::Ryujinx | crate::sources::SourceType::Yuzu => self.install_rom(&install_id, game_id, source).await,
            crate::sources::SourceType::RetroArch => self.install_retroarch(&install_id, game_id).await,
            crate::sources::SourceType::Manual => self.install_manual(&install_id, game_id).await,
        };

        match result {
            Ok(_) => {
                self.database.complete_install(&install_id, true, None).await?;
                // Atualiza game como instalado
                if let Some(mut game) = database.get_game(game_id).await? {
                    game.installed = true;
                    database.upsert_game(&game).await?;
                }
            }
            Err(e) => {
                self.database.complete_install(&install_id, false, Some(e.to_string())).await?;
                return Err(e);
            }
        }

        Ok(())
    }

    async fn install_steam(&self, install_id: &str, game_id: &str) -> Result<()> {
        self.update_progress(install_id, InstallStatus::Downloading, 0.0, 0, 0, None, Some("Starting SteamCMD...".to_string())).await?;

        let app_id = game_id.strip_prefix("steam:").unwrap_or(game_id);

        // steamcmd +login anonymous +app_update <app_id> validate +quit
        let mut cmd = tokio::process::Command::new("steamcmd");
        cmd.args([
            "+@sSteamCmdForcePlatformType", "windows",
            "+login", "anonymous",
            "+app_update", app_id, "validate",
            "+quit"
        ]);

        // TODO: Parse output para progress
        let output = cmd.output().await?;

        if !output.status.success() {
            return Err(color_eyre::eyre::eyre!("steamcmd failed: {}", String::from_utf8_lossy(&output.stderr)));
        }

        self.update_progress(install_id, InstallStatus::Completed, 1.0, 0, 0, None, Some("Install complete".to_string())).await?;
        Ok(())
    }

    async fn install_heroic(&self, install_id: &str, game_id: &str) -> Result<()> {
        self.update_progress(install_id, InstallStatus::Downloading, 0.0, 0, 0, None, Some("Starting Heroic CLI...".to_string())).await?;

        // heroic --headless install <game_id>
        let mut cmd = tokio::process::Command::new("heroic");
        cmd.args(["--headless", "install", game_id]);

        let output = cmd.output().await?;

        if !output.status.success() {
            return Err(color_eyre::eyre::eyre!("heroic install failed: {}", String::from_utf8_lossy(&output.stderr)));
        }

        self.update_progress(install_id, InstallStatus::Completed, 1.0, 0, 0, None, Some("Install complete".to_string())).await?;
        Ok(())
    }

    async fn install_lutris(&self, install_id: &str, game_id: &str) -> Result<()> {
        self.update_progress(install_id, InstallStatus::Downloading, 0.0, 0, 0, None, Some("Starting Lutris...".to_string())).await?;

        // lutris -i <script> --no-gui
        let mut cmd = tokio::process::Command::new("lutris");
        cmd.args(["-i", game_id, "--no-gui"]);

        let output = cmd.output().await?;

        if !output.status.success() {
            return Err(color_eyre::eyre::eyre!("lutris install failed: {}", String::from_utf8_lossy(&output.stderr)));
        }

        self.update_progress(install_id, InstallStatus::Completed, 1.0, 0, 0, None, Some("Install complete".to_string())).await?;
        Ok(())
    }

    async fn install_rom(&self, install_id: &str, game_id: &str, source: crate::sources::SourceType) -> Result<()> {
        // Para emuladores, instalação = copiar ROM para pasta de jogos
        // O usuário deve fornecer a ROM - aqui só registra
        self.update_progress(install_id, InstallStatus::Configuring, 1.0, 0, 0, None, Some("ROM ready".to_string())).await?;
        Ok(())
    }

    async fn install_retroarch(&self, install_id: &str, game_id: &str) -> Result<()> {
        // Instala core + ROM
        self.update_progress(install_id, InstallStatus::Completed, 1.0, 0, 0, None, Some("Ready".to_string())).await?;
        Ok(())
    }

    async fn install_manual(&self, install_id: &str, game_id: &str) -> Result<()> {
        self.update_progress(install_id, InstallStatus::Completed, 1.0, 0, 0, None, Some("Manual entry added".to_string())).await?;
        Ok(())
    }

    async fn update_progress(&self, install_id: &str, status: InstallStatus, progress: f32, downloaded: u64, total: u64, current_file: Option<String>, message: Option<String>) -> Result<()> {
        self.database.update_install_progress(install_id, progress, downloaded, &format!("{:?}", status).to_lowercase()).await?;
        Ok(())
    }
}