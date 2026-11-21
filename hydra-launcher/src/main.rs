// main.rs - Hydra Launcher Entry Point
mod app;
mod sources;
mod ui;
mod database;
mod install;

use std::sync::Arc;
use color_eyre::Result;
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};

#[tokio::main]
async fn main() -> Result<()> {
    // Inicializa logging
    tracing_subscriber::registry()
        .with(tracing_subscriber::EnvFilter::from_default_env())
        .with(tracing_subscriber::fmt::layer())
        .init();

    color_eyre::install()?;

    tracing::info!("Starting Hydra Launcher v{}", env!("CARGO_PKG_VERSION"));

    // Inicializa aplicação
    let app = app::App::new().await?;

    // Roda loop principal
    app.run().await?;

    Ok(())
}