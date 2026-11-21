#!/usr/bin/env bash
# ============================================================
# Setup ROM directories for emulators
# Run as user 'gamer' after first boot
# ============================================================
set -euo pipefail

echo "Setting up ROM directories..."

# Diretórios base
GAMES1="/games/1"
GAMES2="/games/2"

# Cria estrutura
for base in "$GAMES1" "$GAMES2"; do
    mkdir -p "$base"/{switch,3ds,wii,gc,ds,n64,gba,gb,nes,snes,ps1,ps2,psp,dc,arcade}
    mkdir -p "$base"/{covers,shaders,saves,states}
done

# Symlinks convenientes
mkdir -p "$HOME/games"
ln -sf "$GAMES1" "$HOME/games/1"
ln -sf "$GAMES2" "$HOME/games/2"

echo "Created:"
echo "  $GAMES1/{switch,3ds,wii,gc,ds,n64,gba,gb,nes,snes,ps1,ps2,psp,dc,arcade}"
echo "  $GAMES2/{switch,3ds,wii,gc,ds,n64,gba,gb,nes,snes,ps1,ps2,psp,dc,arcade}"
echo "  ~/games/1 -> $GAMES1"
echo "  ~/games/2 -> $GAMES2"

# Permissões (dono gamer)
sudo chown -R gamer:gamer "$GAMES1" "$GAMES2"

echo ""
echo "ROM directories ready!"
echo "Place your ROMs in the appropriate folders."
echo ""
echo "Examples:"
echo "  Switch (Ryujinx/yuzu):     /games/1/switch/ or /games/2/switch/"
echo "  3DS (Citra):               /games/1/3ds/"
echo "  Wii/GC (Dolphin):          /games/1/wii/ and /games/1/gc/"
echo "  DS (melonDS):              /games/1/ds/"
echo "  N64 (Parallel/Rosalie):    /games/1/n64/"
echo "  GBA (mgba):                /games/1/gba/"
echo "  GB/GBC (Gambatte):         /games/1/gb/"
echo "  NES (Mesen):               /games/1/nes/"
echo "  SNES (Snes9x):             /games/1/snes/"
echo "  PS1 (Beetle/Mednafen):     /games/1/ps1/"
echo "  PS2 (PCSX2):               /games/1/ps2/"
echo "  PSP (PPSSPP):              /games/1/psp/"
echo "  Dreamcast (Flycast):       /games/1/dc/"