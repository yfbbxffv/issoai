{ config, pkgs, ... }:

{
  # Boot: systemd-boot (UEFI only, sem GRUB)
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.efi.efiSysMountPoint = "/boot/efi";

  # UKI (Unified Kernel Image) - kernel + initrd + cmdline em um .efi
  # Mais rápido, atomic, suporta secure boot futuro
  boot.loader.generationsDir.enable = true;
  boot.loader.generationsDir.copyKernels = true;

  # Configuração do UKI
  boot.loader.uki = {
    enable = true;
    # UKI será assinado futuramente se Secure Boot for ativado
    # Por enquanto, não assina
    signKey = null;
    signCert = null;
  };

  # Timeout do bootloader (segundos)
  boot.loader.timeout = 2;

  # Console
  boot.console.logLevel = 3;
  boot.plymouth.enable = false; # Sem splash - boot mais rápido

  # Parâmetros extras para o UKI
  boot.loader.kernelParams = [
    "rootflags=subvol=@"
    "rw"
  ];

  # Limpa kernels antigos automaticamente (mantém 2 gerações)
  boot.loader.generationsDir.cleanup = {
    enable = true;
    generations = 2;
  };
}