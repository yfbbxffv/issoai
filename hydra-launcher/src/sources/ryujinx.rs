// sources/ryujinx.rs - Ryujinx source
use std::path::{Path, PathBuf};
use async_trait::async_trait;
use color_eyre::Result;
use tracing::{info, warn, debug};
use serde::{Deserialize, Serialize};
use tokio::fs;

use crate::sources::{GameSource, SourceType, InstallInfo, InstallMethod, LaunchCommand};
use crate::database::GameEntry;
use crate::app::Config;

#[derive(Debug, Deserialize, Serialize)]
struct RyujinxConfig {
    #[serde(default)]
    games: Vec<RyujinxGame>,
}

#[derive(Debug, Deserialize, Serialize)]
struct RyujinxGame {
    name: String,
    path: String,
    #[serde(default)]
    game_id: Option<String>,
    #[serde(default)]
    version: Option<String>,
    #[serde(default)]
    developer: Option<String>,
    #[serde(default)]
    publisher: Option<String>,
    #[serde(default)]
    release_date: Option<String>,
    #[serde(default)]
    description: Option<String>,
    #[serde(default)]
    icon_path: Option<String>,
}

pub struct RyujinxSource {
    config: Config,
    ryujinx_path: PathBuf,
    config_path: PathBuf,
    games_dir: PathBuf,
}

impl RyujinxSource {
    pub async fn new(config: &Config) -> Result<Self> {
        let ryujinx_path = if let Some(p) = &config.ryujinx_path {
            p.clone()
        } else {
            // Locais padrão do Ryujinx
            let candidates = [
                dirs::home_dir().unwrap().join(".local/share/Ryujinx"),
                dirs::home_dir().unwrap().join(".config/Ryujinx"),
                PathBuf::from("/home/gamer/.local/share/Ryujinx"),
            ];
            candidates.into_iter().find(|p| p.exists())
                .ok_or_else(|| color_eyre::eyre::eyre!("Ryujinx config not found"))?
        };

        let config_path = ryujinx_path.join("config.json");
        let games_dir = ryujinx_path.join("games");

        info!("Ryujinx found at: {:?}", ryujinx_path);

        Ok(Self {
            config: config.clone(),
            ryujinx_path,
            config_path,
            games_dir,
        })
    }

    async fn load_config(&self) -> Result<RyujinxConfig> {
        if !self.config_path.exists() {
            return Ok(RyujinxConfig { games: vec![] });
        }
        let content = fs::read_to_string(&self.config_path).await?;
        let config: RyujinxConfig = serde_json::from_str(&content)?;
        Ok(config)
    }

    fn find_roms(&self) -> Vec<PathBuf> {
        let mut roms = Vec::new();
        let search_dirs = [
            self.games_dir.clone(),
            dirs::home_dir().unwrap().join("games/switch"),
            dirs::home_dir().unwrap().join("Games/Switch"),
            PathBuf::from("/games/1/switch"),
            PathBuf::from("/games/2/switch"),
        ];

        for dir in search_dirs {
            if dir.exists() {
                Self::find_roms_recursive(&dir, &mut roms);
            }
        }
        roms
    }

    fn find_roms_recursive(dir: &Path, roms: &mut Vec<PathBuf>) {
        if let Ok(entries) = std::fs::read_dir(dir) {
            for entry in entries.flatten() {
                let path = entry.path();
                if path.is_dir() {
                    Self::find_roms_recursive(&path, roms);
                } else if let Some(ext) = path.extension() {
                    let ext_str = ext.to_string_lossy().to_lowercase();
                    if matches!(ext_str.as_str(), "nsp" | "xci" | "nsz" | "xcz") {
                        roms.push(path);
                    }
                }
            }
        }
    }

    fn rom_to_game_entry(&self, rom_path: &Path, ryujinx_config: &RyujinxConfig) -> GameEntry {
        let file_name = rom_path.file_stem().unwrap().to_string_lossy();
        let name = ryujinx_config.games.iter()
            .find(|g| g.path == rom_path.to_string_lossy())
            .map(|g| g.name.clone())
            .unwrap_or_else(|| file_name.to_string());

        let game_id = format!("ryujinx:{}", blake3::hash(rom_path.as_os_str().as_encoded_bytes()).to_hex().to_string()[..16].to_string());

        GameEntry {
            id: game_id.clone(),
            name,
            source: SourceType::Ryujinx,
            cover: self.find_cover(&rom_path, ryujinx_config),
            installed: true,
            install_path: Some(rom_path.to_path_buf()),
            launch_cmd: vec![
                "ryujinx".to_string(),
                "-g".to_string(),
                rom_path.to_string_lossy().to_string(),
            ],
            launch_env: vec![
                ("GAMESCOPE".to_string(), "1".to_string()),
                ("RUST_BACKTRACE".to_string(), "1".to_string()),
            ],
            metadata: crate::database::GameMetadata {
                hours_played: 0.0,
                last_played: None,
                rating: None,
                tags: vec!["Nintendo Switch".to_string(), "Emulation".to_string()],
                developers: vec![],
                publishers: vec![],
                release_date: None,
                description: None,
            },
        }
    }

    fn find_cover(&self, rom_path: &Path, ryujinx_config: &RyujinxConfig) -> Option<PathBuf> {
        ryujinx_config.games.iter()
            .find(|g| g.path == rom_path.to_string_lossy())
            .and_then(|g| g.icon_path.as_ref())
            .and_then(|p| {
                let path = PathBuf::from(p);
                if path.exists() { Some(path) } else { None }
            })
            .or_else(|| {
                // Procura cover na mesma pasta
                let dir = rom_path.parent()?;
                let candidates = [
                    dir.join("cover.jpg"),
                    dir.join("cover.png"),
                    dir.join("icon.jpg"),
                    dir.join("icon.png"),
                ];
                candidates.into_iter().find(|p| p.exists())
            })
    }
}

#[async_trait]
impl GameSource for RyujinxSource {
    fn name(&self) -> &'static str { "Ryujinx (Nintendo Switch)" }
    fn source_type(&self) -> SourceType { SourceType::Ryujinx }

    async fn scan(&self) -> Result<Vec<GameEntry>> {
        let ryujinx_config = self.load_config().await?;
        let roms = self.find_roms();

        let mut games = Vec::new();
        for rom in roms {
            games.push(self.rom_to_game_entry(&rom, &ryujinx_config));
        }

        info!("Ryujinx scan complete: {} games", games.len());
        Ok(games)
    }

    async fn get_install_info(&self, game_id: &str) -> Result<InstallInfo> {
        // Para Ryujinx, "instalação" = copiar ROM para pasta de jogos
        Ok(InstallInfo {
            game_id: game_id.to_string(),
            name: "Nintendo Switch Game".to_string(),
            install_path: self.games_dir.clone(),
            size_bytes: 0,
            download_url: None,
            install_method: InstallMethod::Ryujinx {
                rom_path: PathBuf::new(), // Será preenchido pelo usuário
            },
        })
    }

    async fn launch_command(&self, game_id: &str) -> Result<LaunchCommand> {
        let ryujinx_config = self.load_config().await?;
        let roms = self.find_roms();

        let rom = roms.iter().find(|r| {
            let id = format!("ryujinx:{}", blake3::hash(r.as_os_str().as_encoded_bytes()).to_hex().to_string()[..16].to_string());
            id == game_id
        });

        if let Some(rom_path) = rom {
            Ok(LaunchCommand {
                command: vec![
                    "ryujinx".to_string(),
                    "-g".to_string(),
                    rom_path.to_string_lossy().to_string(),
                ],
                env: vec![("GAMESCOPE".to_string(), "1".to_string())],
                working_dir: None,
            })
        } else {
            Err(color_eyre::eyre::eyre!("Game not found: {}", game_id))
        }
    }
}