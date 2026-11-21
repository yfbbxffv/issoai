// sources/heroic.rs - Heroic Games Launcher source (placeholder básico)
use std::path::PathBuf;
use async_trait::async_trait;
use color_eyre::Result;
use tracing::info;

use crate::sources::{GameSource, SourceType, InstallInfo, InstallMethod, LaunchCommand};
use crate::database::GameEntry;
use crate::app::Config;

pub struct HeroicSource {
    config: Config,
}

impl HeroicSource {
    pub async fn new(config: &Config) -> Result<Self> {
        info!("Heroic source initialized");
        Ok(Self { config: config.clone() })
    }
}

#[async_trait]
impl GameSource for HeroicSource {
    fn name(&self) -> &'static str { "Heroic Games Launcher" }
    fn source_type(&self) -> SourceType { SourceType::Heroic }

    async fn scan(&self) -> Result<Vec<GameEntry>> {
        // TODO: Parse Heroic config (~/.config/heroic/GamesCache.json)
        Ok(vec![])
    }

    async fn get_install_info(&self, game_id: &str) -> Result<InstallInfo> {
        Ok(InstallInfo {
            game_id: game_id.to_string(),
            name: "Heroic Game".to_string(),
            install_path: PathBuf::from("/games/1/heroic"),
            size_bytes: 0,
            download_url: None,
            install_method: InstallMethod::Heroic { game_id: game_id.to_string(), service: "EGS".to_string() },
        })
    }

    async fn launch_command(&self, game_id: &str) -> Result<LaunchCommand> {
        Ok(LaunchCommand {
            command: vec!["heroic".to_string(), "--run".to_string(), game_id],
            env: vec![("GAMESCOPE".to_string(), "1".to_string())],
            working_dir: None,
        })
    }
}