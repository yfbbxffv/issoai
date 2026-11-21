// sources/emulator.rs - RetroArch / outros emuladores (placeholder)
use std::path::PathBuf;
use async_trait::async_trait;
use color_eyre::Result;
use tracing::info;

use crate::sources::{GameSource, SourceType, InstallInfo, InstallMethod, LaunchCommand};
use crate::database::GameEntry;
use crate::app::Config;

pub struct EmulatorSource {
    config: Config,
}

impl EmulatorSource {
    pub async fn new(config: &Config) -> Result<Self> {
        info!("Emulator source initialized");
        Ok(Self { config: config.clone() })
    }
}

#[async_trait]
impl GameSource for EmulatorSource {
    fn name(&self) -> &'static str { "RetroArch / Emulators" }
    fn source_type(&self) -> SourceType { SourceType::RetroArch }

    async fn scan(&self) -> Result<Vec<GameEntry>> {
        // TODO: Scan RetroArch playlists, ROM directories
        Ok(vec![])
    }

    async fn get_install_info(&self, game_id: &str) -> Result<InstallInfo> {
        Ok(InstallInfo {
            game_id: game_id.to_string(),
            name: "Retro Game".to_string(),
            install_path: PathBuf::from("/games/1/roms"),
            size_bytes: 0,
            download_url: None,
            install_method: InstallMethod::RetroArch { core: "auto".to_string(), rom_path: PathBuf::new() },
        })
    }

    async fn launch_command(&self, game_id: &str) -> Result<LaunchCommand> {
        Ok(LaunchCommand {
            command: vec!["retroarch".to_string(), "-L".to_string(), "core.so".to_string(), game_id],
            env: vec![("GAMESCOPE".to_string(), "1".to_string())],
            working_dir: None,
        })
    }
}