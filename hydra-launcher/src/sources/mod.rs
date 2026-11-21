// sources/mod.rs - Gerenciador de fontes de jogos
pub mod steam;
pub mod ryujinx;
pub mod yuzu;
pub mod lutris;
pub mod heroic;
pub mod emulator;
pub mod manual;

use std::sync::Arc;
use std::path::PathBuf;
use async_trait::async_trait;
use color_eyre::Result;
use tracing::{info, debug};

use crate::database::GameEntry;
use crate::app::Config;

#[async_trait]
pub trait GameSource: Send + Sync {
    fn name(&self) -> &'static str;
    fn source_type(&self) -> SourceType;
    async fn scan(&self) -> Result<Vec<GameEntry>>;
    async fn get_install_info(&self, game_id: &str) -> Result<InstallInfo>;
    async fn launch_command(&self, game_id: &str) -> Result<LaunchCommand>;
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SourceType {
    Steam,
    Lutris,
    Heroic,
    Ryujinx,
    Yuzu,
    RetroArch,
    Manual,
}

#[derive(Debug, Clone)]
pub struct InstallInfo {
    pub game_id: String,
    pub name: String,
    pub install_path: PathBuf,
    pub size_bytes: u64,
    pub download_url: Option<String>,
    pub install_method: InstallMethod,
}

#[derive(Debug, Clone)]
pub enum InstallMethod {
    SteamCmd { app_id: u32 },
    Heroic { game_id: String, service: String }, // EGS, GOG, etc
    Lutris { script_slug: String },
    Ryujinx { rom_path: PathBuf },
    Yuzu { rom_path: PathBuf },
    RetroArch { core: String, rom_path: PathBuf },
    Manual { executable: PathBuf, args: Vec<String> },
}

#[derive(Debug, Clone)]
pub struct LaunchCommand {
    pub command: Vec<String>,
    pub env: Vec<(String, String)>,
    pub working_dir: Option<PathBuf>,
}

pub struct SourceManager {
    sources: Vec<Arc<dyn GameSource>>,
}

impl SourceManager {
    pub async fn new(config: Config) -> Result<Self> {
        let mut sources: Vec<Arc<dyn GameSource>> = Vec::new();

        // Steam
        if let Ok(steam) = steam::SteamSource::new(&config).await {
            sources.push(Arc::new(steam));
            info!("Steam source loaded");
        }

        // Ryujinx
        if let Ok(ryujinx) = ryujinx::RyujinxSource::new(&config).await {
            sources.push(Arc::new(ryujinx));
            info!("Ryujinx source loaded");
        }

        // yuzu
        if let Ok(yuzu) = yuzu::YuzuSource::new(&config).await {
            sources.push(Arc::new(yuzu));
            info!("yuzu source loaded");
        }

        // Lutris
        if let Ok(lutris) = lutris::LutrisSource::new(&config).await {
            sources.push(Arc::new(lutris));
            info!("Lutris source loaded");
        }

        // Heroic
        if let Ok(heroic) = heroic::HeroicSource::new(&config).await {
            sources.push(Arc::new(heroic));
            info!("Heroic source loaded");
        }

        // Manual (ROMs, etc)
        let manual = manual::ManualSource::new(&config).await?;
        sources.push(Arc::new(manual));
        info!("Manual source loaded");

        Ok(Self { sources })
    }

    pub fn get_sources(&self) -> &[Arc<dyn GameSource>] {
        &self.sources
    }

    pub fn get_source(&self, source_type: SourceType) -> Option<Arc<dyn GameSource>> {
        self.sources.iter().find(|s| s.source_type() == source_type).cloned()
    }
}