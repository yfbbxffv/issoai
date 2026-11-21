// ui/mod.rs - Slint UI module
pub mod main_window;

use slint::ComponentHandle;
use color_eyre::Result;
use std::sync::Arc;
use tokio::sync::mpsc;

#[derive(Debug, Clone)]
pub enum UiEvent {
    RefreshGames,
    LaunchGame { game_id: String },
    InstallGame { source: crate::sources::SourceType, game_id: String },
    UninstallGame { game_id: String },
    OpenSettings,
    Quit,
}

pub struct MainWindow {
    window: slint::Window,
    event_sender: mpsc::UnboundedSender<UiEvent>,
}

impl MainWindow {
    pub async fn new(app: Arc<crate::app::App>) -> Result<Self> {
        let (tx, mut rx) = mpsc::unbounded_channel::<UiEvent>();

        // Carrega UI do arquivo .slint
        let window = main_window::MainWindow::new()?;

        // Configura callbacks
        let app_clone = app.clone();
        window.on_refresh_games(move || {
            let _ = tx.send(UiEvent::RefreshGames);
        });

        let app_clone = app.clone();
        window.on_launch_game(move |game_id: slint::SharedString| {
            let _ = tx.send(UiEvent::LaunchGame { game_id: game_id.to_string() });
        });

        let app_clone = app.clone();
        window.on_install_game(move |source: slint::SharedString, game_id: slint::SharedString| {
            let source_type = match source.as_str() {
                "Steam" => crate::sources::SourceType::Steam,
                "Ryujinx" => crate::sources::SourceType::Ryujinx,
                "Yuzu" => crate::sources::SourceType::Yuzu,
                "Lutris" => crate::sources::SourceType::Lutris,
                "Heroic" => crate::sources::SourceType::Heroic,
                "RetroArch" => crate::sources::SourceType::RetroArch,
                _ => crate::sources::SourceType::Manual,
            };
            let _ = tx.send(UiEvent::InstallGame { source: source_type, game_id: game_id.to_string() });
        });

        window.on_quit(move || {
            let _ = tx.send(UiEvent::Quit);
        });

        // Inicializa model
        let games_model = std::rc::Rc::new(slint::VecModel::new(vec![]));
        window.set_games(games_model.clone().into());

        Ok(Self { window, event_sender: tx })
    }

    pub fn get_event_receiver(&self) -> tokio::sync::mpsc::UnboundedReceiver<UiEvent> {
        // Note: This is a simplified version. In reality, you'd need to handle the receiver differently.
        // For now, return a dummy receiver - the actual implementation would share the channel.
        unimplemented!("Use shared channel from App")
    }

    pub fn update_game_list(&self, games: Vec<crate::database::GameEntry>) {
        let model = std::rc::Rc::new(slint::VecModel::new(
            games.into_iter().map(|g| main_window::GameItem {
                id: g.id.into(),
                name: g.name.into(),
                source: format!("{:?}", g.source).into(),
                installed: g.installed,
                cover_path: g.cover.map(|p| p.to_string_lossy().to_string().into()).unwrap_or_default(),
                last_played: g.metadata.last_played.map(|dt| dt.to_rfc3339().into()).unwrap_or_default(),
            }).collect()
        ));
        self.window.set_games(model.into());
    }

    pub fn run(&self) -> Result<()> {
        self.window.run()?;
        Ok(())
    }
}