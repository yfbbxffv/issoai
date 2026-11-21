// sources/manual.rs - Manual source (ROMs, executáveis, scripts)
use std::path::{Path, PathBuf};
use async_trait::async_trait;
use color_eyre::Result;
use tracing::{info, debug};
use walkdir::WalkDir;

use crate::sources::{GameSource, SourceType, InstallInfo, InstallMethod, LaunchCommand};
use crate::database::GameEntry;
use crate::app::Config;

pub struct ManualSource {
    config: Config,
    scan_dirs: Vec<PathBuf>,
}

impl ManualSource {
    pub async fn new(config: &Config) -> Result<Self> {
        let scan_dirs = config.games_paths.clone();

        info!("Manual source initialized with dirs: {:?}", scan_dirs);

        Ok(Self { config: config.clone(), scan_dirs })
    }

    fn is_executable(&self, path: &Path) -> bool {
        if cfg!(target_os = "linux") {
            // Verifica se é ELF executável
            if let Ok(bytes) = std::fs::read(path) {
                if bytes.len() >= 4 && &bytes[0..4] == b"\x7fELF" {
                    return true;
                }
            }
        }
        // Extensões conhecidas
        if let Some(ext) = path.extension() {
            let ext_str = ext.to_string_lossy().to_lowercase();
            matches!(ext_str.as_str(), "exe" | "bat" | "sh" | "appimage" | "AppImage")
        } else {
            false
        }
    }

    fn is_rom(&self, path: &Path) -> bool {
        if let Some(ext) = path.extension() {
            let ext_str = ext.to_string_lossy().to_lowercase();
            matches!(ext_str.as_str(),
                // Nintendo
                "nsp" | "xci" | "nsz" | "xcz" |     // Switch
                "3ds" | "cia" |                       // 3DS
                "wbfs" | "iso" | "gcm" | "rvz" |     // Wii/GC
                "nds" |                               // DS
                "z64" | "n64" | "v64" |               // N64
                "gb" | "gbc" | "gba" |                // Game Boy
                "nes" | "sfc" | "smc" |               // NES/SNES
                // Outros
                "iso" | "cue" | "bin" | "chd" |       // PS1/PS2/DC
                "zip" | "7z" | "rar"                  // Archives
            )
        } else {
            false
        }
    }

    fn detect_emulator_for_rom(&self, path: &Path) -> Option<(SourceType, Vec<String>)> {
        if let Some(ext) = path.extension() {
            let ext_str = ext.to_string_lossy().to_lowercase();
            match ext_str.as_str() {
                "nsp" | "xci" | "nsz" | "xcz" => Some((SourceType::Ryujinx, vec!["ryujinx".to_string(), "-g".to_string()])),
                "3ds" | "cia" => Some((SourceType::RetroArch, vec!["retroarch".to_string(), "-L".to_string(), "citra_libretro.so".to_string()])),
                "wbfs" | "iso" | "gcm" | "rvz" => Some((SourceType::RetroArch, vec!["retroarch".to_string(), "-L".to_string(), "dolphin_libretro.so".to_string()])),
                "nds" => Some((SourceType::RetroArch, vec!["retroarch".to_string(), "-L".to_string(), "melonds_libretro.so".to_string()])),
                "z64" | "n64" | "v64" => Some((SourceType::RetroArch, vec!["retroarch".to_string(), "-L".to_string(), "parallel_n64_libretro.so".to_string()])),
                "gb" | "gbc" | "gba" => Some((SourceType::RetroArch, vec!["retroarch".to_string(), "-L".to_string(), "mgba_libretro.so".to_string()])),
                "nes" | "sfc" | "smc" => Some((SourceType::RetroArch, vec!["retroarch".to_string(), "-L".to_string(), "snes9x_libretro.so".to_string()])),
                _ => None,
            }
        } else {
            None
        }
    }
}

#[async_trait]
impl GameSource for ManualSource {
    fn name(&self) -> &'static str { "Manual / ROMs" }
    fn source_type(&self) -> SourceType { SourceType::Manual }

    async fn scan(&self) -> Result<Vec<GameEntry>> {
        let mut games = Vec::new();

        for dir in &self.scan_dirs {
            if !dir.exists() { continue; }

            for entry in WalkDir::new(dir).max_depth(3).into_iter().filter_map(|e| e.ok()) {
                let path = entry.path();
                if !path.is_file() { continue; }

                if self.is_executable(path) {
                    games.push(self.executable_to_game_entry(path));
                } else if self.is_rom(path) {
                    if let Some(game) = self.rom_to_game_entry(path) {
                        games.push(game);
                    }
                }
            }
        }

        info!("Manual scan complete: {} games", games.len());
        Ok(games)
    }

    fn executable_to_game_entry(&self, path: &Path) -> GameEntry {
        let name = path.file_stem().unwrap().to_string_lossy().to_string();
        let game_id = format!("manual:{}", blake3::hash(path.as_os_str().as_encoded_bytes()).to_hex().to_string()[..16].to_string());

        GameEntry {
            id: game_id,
            name,
            source: SourceType::Manual,
            cover: self.find_cover(path),
            installed: true,
            install_path: Some(path.parent().unwrap().to_path_buf()),
            launch_cmd: vec![path.to_string_lossy().to_string()],
            launch_env: vec![("GAMESCOPE".to_string(), "1".to_string())],
            metadata: crate::database::GameMetadata {
                hours_played: 0.0,
                last_played: None,
                rating: None,
                tags: vec!["Manual".to_string()],
                developers: vec![],
                publishers: vec![],
                release_date: None,
                description: None,
            },
        }
    }

    fn rom_to_game_entry(&self, path: &Path) -> Option<GameEntry> {
        let (source_type, base_cmd) = self.detect_emulator_for_rom(path)?;
        let name = path.file_stem().unwrap().to_string_lossy().to_string();
        let game_id = format!("{:?}:{}", source_type, blake3::hash(path.as_os_str().as_encoded_bytes()).to_hex().to_string()[..16].to_string()).to_lowercase();

        let mut cmd = base_cmd;
        cmd.push(path.to_string_lossy().to_string());

        Some(GameEntry {
            id: game_id,
            name,
            source: source_type,
            cover: self.find_cover(path),
            installed: true,
            install_path: Some(path.parent().unwrap().to_path_buf()),
            launch_cmd: cmd,
            launch_env: vec![("GAMESCOPE".to_string(), "1".to_string())],
            metadata: crate::database::GameMetadata {
                hours_played: 0.0,
                last_played: None,
                rating: None,
                tags: vec!["ROM".to_string(), "Emulation".to_string()],
                developers: vec![],
                publishers: vec![],
                release_date: None,
                description: None,
            },
        })
    }

    fn find_cover(&self, path: &Path) -> Option<PathBuf> {
        let dir = path.parent()?;
        let stem = path.file_stem()?;
        let candidates = [
            dir.join("cover.jpg"),
            dir.join("cover.png"),
            dir.join(format!("{}.jpg", stem.to_string_lossy())),
            dir.join(format!("{}.png", stem.to_string_lossy())),
            dir.join("icon.jpg"),
            dir.join("icon.png"),
        ];
        candidates.into_iter().find(|p| p.exists())
    }

    async fn get_install_info(&self, game_id: &str) -> Result<InstallInfo> {
        Ok(InstallInfo {
            game_id: game_id.to_string(),
            name: "Manual Game".to_string(),
            install_path: self.scan_dirs.first().cloned().unwrap_or_default(),
            size_bytes: 0,
            download_url: None,
            install_method: InstallMethod::Manual { executable: PathBuf::new(), args: vec![] },
        })
    }

    async fn launch_command(&self, game_id: &str) -> Result<LaunchCommand> {
        // Para manual, o comando já está no GameEntry
        Err(color_eyre::eyre::eyre!("Use game entry directly"))
    }
}