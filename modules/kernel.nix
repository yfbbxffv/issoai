{ config, pkgs, ... }:

{
  # Kernel: padrão do NixOS (sem CachyOS overlay)
  # boot.kernelPackages = pkgs.linuxPackages;  # padrão, pode omitir

  # Parâmetros de boot otimizados para gaming + NVIDIA
  boot.kernelParams = [
    # Mitigações de segurança desabilitadas (performance)
    "mitigations=off"
    "spec_store_bypass_disable=off"
    "spectre_v2=off"
    "l1tf=off"
    "mds=off"
    "tsx_async_abort=off"

    # CPU idle / C-states - performance máxima
    "processor.max_cstate=1"
    "idle=poll"
    "intel_idle.max_cstate=0"

    # Preemption total (PREEMPT_RT style)
    "preempt=full"
    "threadirqs"

    # Huge pages transparentes
    "transparent_hugepage=always"

    # NVMe power management off
    "nvme_core.default_ps_max_latency_us=0"
    "nvme_core.apst=0"

    # NVIDIA specific
    "nvidia-drm.modeset=1"
    "nvidia-drm.fbdev=1"

    # IOMMU / VFIO (para futuro passthrough se quiser)
    "intel_iommu=on"
    "iommu=pt"

    # Boot splash silencioso
    "quiet"
    "loglevel=3"
    "rd.udev.log_level=3"
    "systemd.show_status=auto"
  ];

  # Módulos carregados no initrd (early load NVIDIA)
  boot.initrd.kernelModules = [
    "nvidia"
    "nvidia_modeset"
    "nvidia_uvm"
    "nvidia_drm"
    "vfio"
    "vfio_pci"
    "vfio_iommu_type1"
    "uinput"
    "hid_generic"
    "usbhid"
    "xhci_pci"
    "nvme"
  ];

  # Módulos carregados após boot
  boot.kernelModules = [
    "nvidia"
    "nvidia_modeset"
    "nvidia_uvm"
    "nvidia_drm"
    "vfio"
    "vfio_pci"
    "uinput"
  ];

  # Microcode Intel (i3-10100F = Comet Lake)
  hardware.cpu.intel.updateMicrocode = true;
  hardware.cpu.intel.microcodePackage = pkgs.intel-microcode;

  # Kernel locks / debugging desabilitado
  boot.kernel.sysctl = {
    "kernel.lockdown" = 0;
    "kernel.yama.ptrace_scope" = 0;
  };
}