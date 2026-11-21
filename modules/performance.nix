{ config, pkgs, ... }:

{
  # ============================================================
  # PERFORMANCE TUNING - i3-10100F + GTX 1660 Super
  # ============================================================

  # CPU Governor: performance
  services.cpupower = {
    enable = true;
    governor = "performance";
    # energy_performance_preference = "performance";
  };

  # Thermald para gerenciamento térmico
  services.thermald.enable = true;

  # ============================================================
  # KERNEL SYSCTL - Gaming optimizations
  # ============================================================
  boot.kernel.sysctl = {
    # Scheduler
    "kernel.sched_autogroup_enabled" = "0";
    "kernel.sched_latency_ns" = "4000000";
    "kernel.sched_min_granularity_ns" = "1000000";
    "kernel.sched_wakeup_granularity_ns" = "2000000";
    "kernel.sched_migration_cost_ns" = "5000000";

    # Memory management
    "vm.swappiness" = "10"; # zram já é rápido
    "vm.vfs_cache_pressure" = "50";
    "vm.dirty_ratio" = "15";
    "vm.dirty_background_ratio" = "5";
    "vm.dirty_expire_centisecs" = "3000";
    "vm.dirty_writeback_centisecs" = "500";

    # Huge pages
    "vm.nr_hugepages" = "0";
    "vm.hugetlb_shm_group" = "0";

    # File system
    "fs.file-max" = "2097152";
    "fs.inotify.max_user_watches" = "1048576";
    "fs.inotify.max_user_instances" = "1024";

    # Kernel
    "kernel.pid_max" = "4194304";
    "kernel.threads-max" = "4194304";
  };

  # ============================================================
  # TUNED PROFILE - Gaming
  # ============================================================
  services.tuned = {
    enable = true;
    profiles = [
      "latency-performance"
      "network-throughput"
      "desktop"
    ];
    # Profile customizado para gaming
    customProfiles = {
      "gameos-gaming" = {
        summary = "GameOS Gaming Profile";
        description = "Optimized for gaming on i3-10100F + GTX 1660 Super";
        cpu = {
          governor = "performance";
          energy_performance_preference = "performance";
          min_perf_pct = 100;
        };
        disk = {
          readahead = 4096;
        };
        net = {
          tcp_congestion_control = "bbr";
        };
        sysctl = {
          "kernel.sched_latency_ns" = "4000000";
          "kernel.sched_min_granularity_ns" = "1000000";
          "vm.swappiness" = "10";
        };
      };
    };
    activeProfile = "gameos-gaming";
  };

  # ============================================================
  # EARLY OOM DAEMON - Previne freeze total
  # ============================================================
  services.earlyoom = {
    enable = true;
    memoryThreshold = 5; # 5% RAM livre
    swapThreshold = 90;  # 90% swap usado
    enableNotifications = true;
    prefer = [ "steam" "lutris" "heroic" "ryujinx" "yuzu" "gamescope" ];
    avoid = [ "systemd" "Xwayland" "pipewire" "dbus" ];
  };

  # ============================================================
  # PREEMPT-RT / SCHED_EXT (via kernel cachyos)
  # ============================================================
  # Já configurado no kernel.nix (linux-cachyos com BORE/EEVDF)
  # Aqui só garantimos que sched-ext está disponível
  environment.systemPackages = with pkgs; [
    scx-scheds # sched-ext schedulers (rusty, lavd, etc)
  ];

  # ============================================================
  # GPU POWER MANAGEMENT - NVIDIA
  # ============================================================
  # PowerMizer: Prefer Maximum Performance
  systemd.services.nvidia-powerd = {
    description = "NVIDIA Power Management Daemon";
    after = [ "graphical-session.target" ];
    wantedBy = [ "graphical-session.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.nvidia-settings}/bin/nvidia-settings -a '[gpu:0]/GPUPowerMizerMode=1'";
    };
  };

  # ============================================================
  # IO SCHEDULER - NVMe: none (no-op), SATA: bfq
  # ============================================================
  boot.kernel.sysctl."block.nvme.io_scheduler" = "none";
  boot.kernel.sysctl."block.sd.io_scheduler" = "bfq";

  # ============================================================
  # FSTRIM - SSD trim semanal
  # ============================================================
  systemd.timers.fstrim = {
    enable = true;
    timerConfig.OnCalendar = "weekly";
    timerConfig.Persistent = true;
  };

  # ============================================================
  # PRELOAD - Carrega libs comuns na RAM
  # ============================================================
  services.prelude = {
    enable = true;
    config = {
      # Apps de gaming para preload
      apps = [
        "steam"
        "lutris"
        "heroic"
        "ryujinx"
        "yuzu"
        "gamescope"
        "retroarch"
      ];
    };
  };

  # ============================================================
  # ZSWAP (além do zram) - Compressão extra
  # ============================================================
  boot.kernel.sysctl = {
    "vm.zswap.enabled" = "1";
    "vm.zswap.compressor" = "zstd";
    "vm.zswap.max_pool_percent" = "20";
    "vm.zswap.zpool" = "z3fold";
  };
}