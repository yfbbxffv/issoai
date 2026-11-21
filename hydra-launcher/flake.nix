{
  description = "Hydra Launcher - GameOS Game Launcher";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    rust-overlay.url = "github:oxalica/rust-overlay";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, rust-overlay, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [
            (import rust-overlay)
          ];
        };

        # Rust toolchain estável + nightly para Slint
        rustToolchain = pkgs.rust-bin.stable.latest.default.override {
          extensions = [ "rust-src" "rust-analyzer" "clippy" "rustfmt" ];
        };

        # Mold linker (mais rápido)
        mold = pkgs.mold;

        # Dependências de build
        buildDeps = with pkgs; [
          pkg-config
          cmake
          ninja
          clang
          llvm
          mold
          wayland-protocols
          libxkbcommon
          libxcb
          libx11
          libglvnd
          vulkan-headers
          vulkan-loader
          freetype
          fontconfig
          harfbuzz
          libpng
          libjpeg
          sqlite
          openssl
          zstd
        ];

        # Cargo config para mold
        cargoConfig = {
          target."cfg(all(target_os = \"linux\", target_env = \"gnu\"))".linker = "clang";
          target."cfg(all(target_os = \"linux\", target_env = \"gnu\"))".rustflags = [
            "-C" "link-arg=-fuse-ld=mold"
            "-C" "link-arg=-Wl,--as-needed"
            "-C" "link-arg=-Wl,-O2"
            "-C" "target-cpu=native"
          ];
        };
      in
      {
        packages.hydra-launcher = pkgs.rustPlatform.buildRustPackage {
          pname = "hydra-launcher";
          version = "0.1.0";
          src = ./.;
          cargoSha256 = ""; # Será preenchido na primeira build

          nativeBuildInputs = buildDeps ++ [ pkgs.slint-build ];
          buildInputs = with pkgs; [
            wayland
            libxkbcommon
            libxcb
            libx11
            libglvnd
            vulkan-loader
            freetype
            fontconfig
            harfbuzz
            libpng
            libjpeg
            sqlite
            openssl
            zstd
          ];

          # Cargo environment
          CARGO_NET_GIT_FETCH_WITH_CLI = true;
          RUSTFLAGS = "-C target-cpu=native -C link-arg=-fuse-ld=mold";
          CARGO_INCREMENTAL = 1;

          # Build phase
          preBuild = ''
            export CARGO_TARGET_DIR="${CARGO_TARGET_DIR:-target}"
            mkdir -p $CARGO_TARGET_DIR
          '';

          # Install phase
          installPhase = ''
            mkdir -p $out/bin
            cp target/release/hydra-launcher $out/bin/
            mkdir -p $out/share/applications
            cat > $out/share/applications/hydra-launcher.desktop <<EOF
            [Desktop Entry]
            Name=Hydra Launcher
            Comment=GameOS Unified Game Launcher
            Exec=hydra-launcher
            Icon=hydra-launcher
            Type=Application
            Categories=Game;
            StartupNotify=true
            EOF
            mkdir -p $out/share/icons/hicolor/256x256/apps
            cp assets/icons/hydra-logo.png $out/share/icons/hicolor/256x256/apps/hydra-launcher.png || true
          '';

          meta = with pkgs.lib; {
            description = "Hydra Launcher - Unified gaming frontend for Steam, Ryujinx, yuzu, and more";
            homepage = "https://github.com/seu-usuario/gameos";
            license = licenses.mit;
            platforms = [ "x86_64-linux" ];
            maintainers = with maintainers; [ ];
          };
        };

        # Dev shell para desenvolvimento
        devShells.default = pkgs.mkShell {
          name = "hydra-launcher-dev";
          buildInputs = buildDeps ++ [ pkgs.slint-build pkgs.cargo-expand pkgs.cargo-watch ];
          RUSTFLAGS = "-C target-cpu=native -C link-arg=-fuse-ld=mold";
          SHELL_HOOK = ''
            echo "Hydra Launcher Dev Shell"
            echo "Run: cargo run"
            echo "Watch: cargo watch -x run"
          '';
        };

        # Formatter
        formatter = pkgs.alejandra;
      }
    );
}