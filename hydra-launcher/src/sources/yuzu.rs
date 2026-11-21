// sources/yuzu.rs - yuzu source
use std::path::{Path, PathBuf};
use async_trait::async_trait;
use color_eyre::Result;
use tracing::{info, warn, debug};
use tokio::fs;

use crate::sources::{GameSource, SourceType, InstallInfo, InstallMethod, LaunchCommand};
use crate::database::GameEntry;
use crate::app::Config;

#[derive(Debug, serde::Deserialize)]
struct YuzuConfig {
    #[serde(default)]
    games: Vec<YuzuGame>,
}

#[derive(Debug, serde::Deserialize)]
struct YuzuGame {
    name: String,
    path: String,
    #[serde(default)]
    game_id: Option<String>,
    #[serde(default)]
    version: Option<String>,
}

pub struct YuzuSource {
    config: Config,
    yuzu_path: PathBuf,
    config_path: PathBuf,
    games_dir: PathBuf,
}

impl YuzuSource {
    pub async fn new(config: &Config) -> Result<Self> {
        let yuzu_path = if let Some(p) = &config.yuzu_path {
            p.clone()
        } else {
            let candidates = [
                dirs::home_dir().unwrap().join(".local/share/yuzu"),
                dirs::home_dir().unwrap().join(".config/yuzu"),
                PathBuf::from("/home/gamer/.local/share/yuzu"),
            ];
            candidates.into_iter().find(|p| p.exists())
                .ok_or_else(|| color_eyre::eyre::eyre!("yuzu config not found"))?
        };

        let config_path = yuzu_path.join("config/qt-config.ini");
        let games_dir = yuzu_path.join("games");

        info!("yuzu found at: {:?}", yuzu_path);

        Ok(Self {
            config: config.clone(),
            yuzu_path,
            config_path,
            games_dir,
        })
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

    fn rom_to_game_entry(&self, rom_path: &Path) -> GameEntry {
        let file_name = rom_path.file_stem().unwrap().to_string_lossy();
        let game_id = format!("yuzu:{}", blake3::hash(rom_path.as_os_str().as_encoded_bytes()).to_hex().to_string()[..16].to_string());

        GameEntry {
            id: game_id.clone(),
            name: file_name.to_string(),
            source: SourceType::Yuzu,
            cover: self.find_cover(&rom_path),
            installed: true,
            install_path: Some(rom_path.to_path_buf()),
            launch_cmd: vec![
                "yuzu".to_string(),
                "-f".to_string(),
                "-g".to_string(),
                rom_path.to_string_lossy().to_string(),
            ],
            launch_env: vec![
                ("GAMESCOPE".to_string(), "1".to_string()),
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

    fn find_cover(&self, rom_path: &Path) -> Option<PathBuf> {
        let dir = rom_path.parent()?;
        let candidates = [
            dir.join("cover.jpg"),
            dir.join("cover.png"),
            dir.join("icon.jpg"),
            dir.join("icon.png"),
            self.yuzu_path.join("cache/icons").join(format!("{}.png", rom_path.file_stem()?.to_string_lossy())),
        ];
        candidates.into_iter().find(|p| p.exists())
    }
}

#[async_trait]
impl GameSource for YuzuSource {
    fn name(&self) -> &'static str { "yuzu (Nintendo Switch)" }
    fn source_type(&self) -> SourceType { SourceType::Yuzu }

    async fn scan(&self) -> Result<Vec<GameEntry>> {
        let roms = self.find_roms();

        let mut games = Vec::new();
        for rom in roms {
            games.push(self.rom_to_game_entry(&rom));
        }

        info!("yuzu scan complete: {} games", games.len());
        Ok(games)
    }

    async fn get_install_info(&self, game_id: &str) -> Result<InstallInfo> {
        Ok(InstallInfo {
            game_id: game_id.to_string(),
            name: "Nintendo Switch Game".to_string(),
            install_path: self.games_dir.clone(),
            size_bytes: 0,
            download_url: None,
            install_method: InstallMethod::Yuzu {
                rom_path: PathBuf::new(),
            },
        })
    }

    async fn launch_command(&self, game_id: &str) -> Result<LaunchCommand> {
        let roms = self.find_roms();

        let rom = roms.iter().find(|r| {
            let id = format!("yuzu:{}", blake3::hash(r.as_os_str().as_encoded_bytes()).to_hex().to_string()[..16].to_string());
            id == game_id
        });

        if let Some(rom_path) = rom {
            Ok(LaunchCommand {
                command: vec![
                    "yuzu".to_string(),
                    "-f".to_string(),
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