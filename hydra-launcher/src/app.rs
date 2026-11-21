// app.rs - Aplicação principal
use std::sync::Arc;
use std::path::PathBuf;
use tokio::sync::RwLock;
use color_eyre::Result;
use tracing::{info, error};

use crate::sources::{SourceManager, GameSource};
use crate::database::{Database, GameEntry};
use crate::install::{InstallManager, InstallProgress};
use crate::ui::{MainWindow, UiEvent};

pub struct App {
    source_manager: Arc<SourceManager>,
    database: Arc<Database>,
    install_manager: Arc<InstallManager>,
    window: Option<MainWindow>,
    games: Arc<RwLock<Vec<GameEntry>>>,
    config: Config,
}

#[derive(Debug, Clone)]
pub struct Config {
    pub games_paths: Vec<PathBuf>,
    pub steam_path: Option<PathBuf>,
    pub ryujinx_path: Option<PathBuf>,
    pub yuzu_path: Option<PathBuf>,
    pub database_path: PathBuf,
    pub cache_dir: PathBuf,
}

impl Default for Config {
    fn default() -> Self {
        let home = dirs::home_dir().unwrap_or_else(|| PathBuf::from("/home/gamer"));
        Self {
            games_paths: vec![
                home.join("games"),
                PathBuf::from("/games/1"),
                PathBuf::from("/games/2"),
            ],
            steam_path: None, // Auto-detect
            ryujinx_path: None,
            yuzu_path: None,
            database_path: home.join(".local/share/hydra/games.db"),
            cache_dir: home.join(".cache/hydra"),
        }
    }
}

impl App {
    pub async fn new() -> Result<Self> {
        let config = Config::default();

        // Cria diretórios
        tokio::fs::create_dir_all(&config.database_path.parent().unwrap()).await?;
        tokio::fs::create_dir_all(&config.cache_dir).await?;

        // Inicializa banco de dados
        let database = Arc::new(Database::new(&config.database_path).await?);
        database.migrate().await?;

        // Inicializa gerenciador de fontes
        let source_manager = Arc::new(SourceManager::new(config.clone()).await?);

        // Inicializa gerenciador de instalação
        let install_manager = Arc::new(InstallManager::new(config.clone(), database.clone()).await?);

        Ok(Self {
            source_manager,
            database,
            install_manager,
            window: None,
            games: Arc::new(RwLock::new(Vec::new())),
            config,
        })
    }

    pub async fn run(&mut self) -> Result<()> {
        info!("Initializing UI...");

        // Carrega jogos do banco
        self.refresh_games().await?;

        // Cria janela principal
        let window = MainWindow::new(self.clone()).await?;
        self.window = Some(window);

        // Roda loop de eventos
        self.event_loop().await?;

        Ok(())
    }

    async fn event_loop(&self) -> Result<()> {
        let window = self.window.as_ref().unwrap();
        let mut event_receiver = window.get_event_receiver();

        while let Some(event) = event_receiver.recv().await {
            match event {
                UiEvent::RefreshGames => {
                    if let Err(e) = self.refresh_games().await {
                        error!("Failed to refresh games: {}", e);
                    }
                }
                UiEvent::LaunchGame { game_id } => {
                    if let Err(e) = self.launch_game(&game_id).await {
                        error!("Failed to launch game {}: {}", game_id, e);
                    }
                }
                UiEvent::InstallGame { source, game_id } => {
                    let install_manager = self.install_manager.clone();
                    let database = self.database.clone();
                    tokio::spawn(async move {
                        if let Err(e) = install_manager.install(source, game_id, database).await {
                            error!("Install failed: {}", e);
                        }
                    });
                }
                UiEvent::UninstallGame { game_id } => {
                    // TODO: Implement uninstall
                }
                UiEvent::OpenSettings => {
                    // TODO: Settings window
                }
                UiEvent::Quit => {
                    break;
                }
            }
        }

        Ok(())
    }

    pub async fn refresh_games(&self) -> Result<()> {
        info!("Refreshing game library...");

        // Coleta jogos de todas as fontes
        let mut all_games = Vec::new();

        for source in self.source_manager.get_sources() {
            match source.scan().await {
                Ok(games) => {
                    info!("Found {} games from {}", games.len(), source.name());
                    all_games.extend(games);
                }
                Err(e) => {
                    error!("Failed to scan {}: {}", source.name(), e);
                }
            }
        }

        // Atualiza banco de dados
        for game in &all_games {
            self.database.upsert_game(game).await?;
        }

        // Atualiza cache em memória
        let mut games_lock = self.games.write().await;
        *games_lock = all_games;

        // Notifica UI
        if let Some(window) = &self.window {
            window.update_game_list(games_lock.clone());
        }

        info!("Library refreshed: {} total games", games_lock.len());
        Ok(())
    }

    pub async fn launch_game(&self, game_id: &str) -> Result<()> {
        let games = self.games.read().await;
        let game = games.iter().find(|g| g.id == game_id)
            .ok_or_else(|| color_eyre::eyre::eyre!("Game not found: {}", game_id))?;

        info!("Launching game: {} ({})", game.name, game.id);

        // Executa comando de launch
        let mut cmd = tokio::process::Command::new(&game.launch_cmd[0]);
        cmd.args(&game.launch_cmd[1..]);
        cmd.envs(&game.launch_env);
        cmd.spawn()?;

        // Atualiza last_played
        self.database.update_last_played(game_id).await?;

        Ok(())
    }

    pub fn get_games(&self) -> Arc<RwLock<Vec<GameEntry>>> {
        self.games.clone()
    }

    pub fn get_install_manager(&self) -> Arc<InstallManager> {
        self.install_manager.clone()
    }
}