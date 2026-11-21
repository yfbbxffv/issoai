// build.rs - Compila Slint UI e recursos
fn main() -> Result<(), Box<dyn std::error::Error>> {
    // Compila arquivos .slint
    slint_build::compile("src/ui/main_window.slint")?;

    // Copia assets para o diretório de saída
    let out_dir = std::env::var("OUT_DIR")?;
    let assets_src = std::path::Path::new("assets");
    let assets_dst = std::path::Path::new(&out_dir).join("assets");

    if assets_src.exists() {
        copy_dir_all(assets_src, &assets_dst)?;
    }

    // Embed metadata
    println!("cargo:rustc-env=HYDRA_VERSION={}", env!("CARGO_PKG_VERSION"));
    println!("cargo:rustc-env=HYDRA_GIT_HASH={}",
        std::process::Command::new("git")
            .args(["rev-parse", "--short", "HEAD"])
            .output()
            .map(|o| String::from_utf8_lossy(&o.stdout).trim().to_string())
            .unwrap_or_else(|_| "unknown".to_string())
    );

    Ok(())
}

fn copy_dir_all(src: &std::path::Path, dst: &std::path::Path) -> std::io::Result<()> {
    std::fs::create_dir_all(dst)?;
    for entry in std::fs::read_dir(src)? {
        let entry = entry?;
        let ty = entry.file_type()?;
        if ty.is_dir() {
            copy_dir_all(&entry.path(), &dst.join(entry.file_name()))?;
        } else {
            std::fs::copy(entry.path(), dst.join(entry.file_name()))?;
        }
    }
    Ok(())
}