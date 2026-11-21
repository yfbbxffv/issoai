// sources/steam.rs - Steam source
use std::path::{Path, PathBuf};
use std::collections::HashMap;
use async_trait::async_trait;
use color_eyre::Result;
use tracing::{info, warn, debug};
use serde::{Deserialize, Serialize};

use crate::sources::{GameSource, SourceType, InstallInfo, InstallMethod, LaunchCommand};
use crate::database::GameEntry;
use crate::app::Config;

#[derive(Debug, Deserialize)]
struct LibraryFolders {
    libraryfolders: HashMap<String, LibraryFolder>,
}

#[derive(Debug, Deserialize)]
struct LibraryFolder {
    path: String,
    apps: HashMap<String, AppInfo>,
}

#[derive(Debug, Deserialize)]
struct AppInfo {
    #[serde(default)]
    name: String,
    #[serde(default)]
    size: Option<u64>,
    #[serde(default)]
    lastplayed: Option<u64>,
}

pub struct SteamSource {
    config: Config,
    steam_path: PathBuf,
    library_paths: Vec<PathBuf>,
}

impl SteamSource {
    pub async fn new(config: &Config) -> Result<Self> {
        // Detecta caminho do Steam
        let steam_path = if let Some(p) = &config.steam_path {
            p.clone()
        } else {
            // Locais padrão
            let candidates = [
                dirs::home_dir().unwrap().join(".steam/steam"),
                dirs::home_dir().unwrap().join(".var/app/com.valvesoftware.Steam/data/steam"),
                PathBuf::from("/home/gamer/.steam/steam"),
            ];
            candidates.into_iter().find(|p| p.exists())
                .ok_or_else(|| color_eyre::eyre::eyre!("Steam not found"))?
        };

        // Lê libraryfolders.vdf
        let library_vdf = steam_path.join("steamapps/libraryfolders.vdf");
        let library_paths = if library_vdf.exists() {
            Self::parse_library_folders(&library_vdf)?
        } else {
            vec![steam_path.join("steamapps")]
        };

        info!("Steam found at: {:?}", steam_path);
        info!("Library paths: {:?}", library_paths);

        Ok(Self {
            config: config.clone(),
            steam_path,
            library_paths,
        })
    }

    fn parse_library_folders(path: &Path) -> Result<Vec<PathBuf>> {
        let content = std::fs::read_to_string(path)?;
        // VDF parsing simplificado - use vdf crate em produção
        let mut paths = vec![path.parent().unwrap().to_path_buf()];

        for line in content.lines() {
            if line.contains("\"path\"") {
                if let Some(start) = line.find('"') {
                    if let Some(end) = line[start+1..].find('"') {
                        let p = &line[start+1..start+1+end];
                        paths.push(PathBuf::from(p).join("steamapps"));
                    }
                }
            }
        }

        Ok(paths)
    }

    fn parse_acf(&self, acf_path: &Path) -> Option<GameEntry> {
        let content = std::fs::read_to_string(acf_path).ok()?;
        let mut app_id = String::new();
        let mut name = String::new();
        let mut install_dir = String::new();
        let mut size: Option<u64> = None;

        for line in content.lines() {
            let line = line.trim();
            if line.starts_with("\"appid\"") {
                app_id = line.split('"').nth(3)?.to_string();
            } else if line.starts_with("\"name\"") {
                name = line.split('"').nth(3)?.to_string();
            } else if line.starts_with("\"installdir\"") {
                install_dir = line.split('"').nth(3)?.to_string();
            } else if line.starts_with("\"SizeOnDisk\"") {
                size = line.split('"').nth(3)?.parse().ok();
            }
        }

        if app_id.is_empty() || name.is_empty() {
            return None;
        }

        let install_path = self.library_paths.iter()
            .find_map(|lib| {
                let p = lib.join("common").join(&install_dir);
                if p.exists() { Some(p) } else { None }
            })
            .unwrap_or_else(|| self.steam_path.join("steamapps/common").join(&install_dir));

        let installed = install_path.exists();

        Some(GameEntry {
            id: format!("steam:{}", app_id),
            name,
            source: super::SourceType::Steam,
            cover: self.find_cover(&app_id),
            installed,
            install_path: if installed { Some(install_path) } else { None },
            launch_cmd: vec![
                "steam".to_string(),
                format!("steam://run/{}", app_id),
            ],
            launch_env: vec![
                ("STEAM_RUNTIME".to_string(), "1".to_string()),
                ("GAMESCOPE".to_string(), "1".to_string()),
            ],
            metadata: crate::database::GameMetadata {
                hours_played: 0.0,
                last_played: None,
                rating: None,
                tags: vec![],
                developers: vec![],
                publishers: vec![],
                release_date: None,
                description: None,
            },
        })
    }

    fn find_cover(&self, app_id: &str) -> Option<PathBuf> {
        // Procura cover em várias localizações
        let candidates = [
            self.steam_path.join("appcache/librarycache").join(format!("{}_hero.jpg", app_id)),
            self.steam_path.join("appcache/librarycache").join(format!("{}_library_hero.jpg", app_id)),
            self.steam_path.join("appcache/librarycache").join(format!("{}_capsule_616x353.jpg", app_id)),
        ];
        candidates.into_iter().find(|p| p.exists())
    }
}

#[async_trait]
impl GameSource for SteamSource {
    fn name(&self) -> &'static str { "Steam" }
    fn source_type(&self) -> SourceType { SourceType::Steam }

    async fn scan(&self) -> Result<Vec<GameEntry>> {
        let mut games = Vec::new();

        for lib_path in &self.library_paths {
            let steamapps = lib_path.join("steamapps");
            if !steamapps.exists() { continue; }

            for entry in std::fs::read_dir(&steamapps)? {
                let entry = entry?;
                let path = entry.path();
                if path.extension().map_or(false, |e| e == "acf") {
                    if let Some(game) = self.parse_acf(&path) {
                        games.push(game);
                    }
                }
            }
        }

        info!("Steam scan complete: {} games", games.len());
        Ok(games)
    }

    async fn get_install_info(&self, game_id: &str) -> Result<InstallInfo> {
        let app_id = game_id.strip_prefix("steam:").unwrap_or(game_id);
        Ok(InstallInfo {
            game_id: game_id.to_string(),
            name: "Unknown".to_string(),
            install_path: self.steam_path.join("steamapps/common").join(app_id),
            size_bytes: 0,
            download_url: None,
            install_method: InstallMethod::SteamCmd { app_id: app_id.parse()? },
        })
    }

    async fn launch_command(&self, game_id: &str) -> Result<LaunchCommand> {
        Ok(LaunchCommand {
            command: vec!["steam".to_string(), format!("steam://run/{}", game_id.strip_prefix("steam:").unwrap_or(game_id))],
            env: vec![("STEAM_RUNTIME".to_string(), "1".to_string()), ("GAMESCOPE".to_string(), "1".to_string())],
            working_dir: None,
        })
    }
}