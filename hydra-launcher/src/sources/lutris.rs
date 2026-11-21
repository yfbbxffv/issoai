// sources/lutris.rs - Lutris source (placeholder básico)
use std::path::PathBuf;
use async_trait::async_trait;
use color_eyre::Result;
use tracing::info;

use crate::sources::{GameSource, SourceType, InstallInfo, InstallMethod, LaunchCommand};
use crate::database::GameEntry;
use crate::app::Config;

pub struct LutrisSource {
    config: Config,
}

impl LutrisSource {
    pub async fn new(config: &Config) -> Result<Self> {
        info!("Lutris source initialized");
        Ok(Self { config: config.clone() })
    }
}

#[async_trait]
impl GameSource for LutrisSource {
    fn name(&self) -> &'static str { "Lutris" }
    fn source_type(&self) -> SourceType { SourceType::Lutris }

    async fn scan(&self) -> Result<Vec<GameEntry>> {
        // TODO: Parse ~/.local/share/lutris/games.db (SQLite)
        Ok(vec![])
    }

    async fn get_install_info(&self, game_id: &str) -> Result<InstallInfo> {
        Ok(InstallInfo {
            game_id: game_id.to_string(),
            name: "Lutris Game".to_string(),
            install_path: PathBuf::from("/games/1/lutris"),
            size_bytes: 0,
            download_url: None,
            install_method: InstallMethod::Lutris { script_slug: game_id.to_string() },
        })
    }

    async fn launch_command(&self, game_id: &str) -> Result<LaunchCommand> {
        Ok(LaunchCommand {
            command: vec!["lutris".to_string(), format!("lutris:rungame/{}", game_id)],
            env: vec![("GAMESCOPE".to_string(), "1".to_string())],
            working_dir: None,
        })
    }
}