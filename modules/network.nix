{ config, pkgs, ... }:

{
  # ============================================================
  # NETWORK - systemd-networkd + systemd-resolved
  # Gaming optimizations: BBR, fq_codel, irqbalance
  # ============================================================

  # NetworkManager DESABILITADO (mais leve)
  networking.networkmanager.enable = false;

  # systemd-networkd para rede cabeada
  systemd.network.enable = true;
  systemd.network.networks = {
    "20-wired" = {
      matchConfig = {
        Type = "ether";
      };
      networkConfig = {
        DHCP = "yes";
        IPv6AcceptRA = true;
        # Gaming: prioridade de pacotes
        DSCP = "EF"; # Expedited Forwarding para jogos
      };
      linkConfig = {
        # Wake on LAN (se quiser)
        WakeOnLan = "magic";
      };
    };
  };

  # WiFi: iwd (mais leve que wpa_supplicant)
  networking.wireless.enable = true;
  networking.wireless.iwd.enable = true;
  networking.wireless.networks = {
    # Redes serão configuradas via iwctl no primeiro boot
    # Ou adicione aqui:
    # "MinhaRede" = { psk = "senha"; };
  };

  # systemd-resolved para DNS
  systemd.resolved.enable = true;
  systemd.resolved.config = {
    DNS = [ "1.1.1.1" "8.8.8.8" "9.9.9.9" ];
    DNSOverTLS = "opportunistic";
    Cache = true;
    DNSSEC = "yes";
    MulticastDNS = "yes";
    LLMNR = "yes";
  };
  networking.useHostResolvConf = true;

  # Hostname
  networking.hostName = "gameos";

  # ============================================================
  # GAMING NETWORK OPTIMIZATIONS
  # ============================================================
  boot.kernel.sysctl = {
    # TCP BBR congestion control (melhor latência/throughput)
    "net.core.default_qdisc" = "fq_codel";
    "net.ipv4.tcp_congestion_control" = "bbr";

    # Buffer sizes otimizados para gaming
    "net.core.rmem_max" = "26214400";
    "net.core.wmem_max" = "26214400";
    "net.ipv4.tcp_rmem" = "4096 87380 26214400";
    "net.ipv4.tcp_wmem" = "4096 65536 26214400";

    # Reduz latência
    "net.ipv4.tcp_low_latency" = "1";
    "net.ipv4.tcp_slow_start_after_idle" = "0";
    "net.ipv4.tcp_no_metrics_save" = "1";

    # Connection tracking (para NAT/P2P)
    "net.netfilter.nf_conntrack_max" = "1048576";
    "net.netfilter.nf_conntrack_tcp_timeout_established" = "1200";

    # IPv6
    "net.ipv6.conf.all.disable_ipv6" = "0";
    "net.ipv6.conf.default.disable_ipv6" = "0";
  };

  # IRQ Balance - distribui interrupções de rede/GPU entre cores
  services.irqbalance = {
    enable = true;
    oneshot = false;
    # Configuração: isola cores para gaming se quiser
    # IRQBALANCE_ARGS = "--foreground --hintpolicy=exact --pid=/run/irqbalance.pid";
  };

  # Firewall mínimo (apenas essenciais)
  networking.firewall = {
    enable = true;
    allowPing = true;
    logRefusedConnections = false;
    logRefusedPackets = false;
    trustedInterfaces = [ "lo" ];
    # Portas para gaming (Steam, UPnP, etc)
    allowedTCPPorts = [ 27015 27016 27017 27018 27019 27020 27021 27022 27023 27024 27025 27026 27027 27028 27029 27030 27031 27032 27033 27034 27035 27036 ];
    allowedUDPPorts = [ 27015 27016 27017 27018 27019 27020 27021 27022 27023 27024 27025 27026 27027 27028 27029 27030 27031 27032 27033 27034 27035 27036 4379 4380 27000 27001 27002 27003 27004 27005 27006 27007 27008 27009 27010 27011 27012 27013 27014 ];
  };

  # UPnP / NAT-PMP para jogos
  services.upnpd = {
    enable = true;
    externalInterface = "eth0"; # Ajuste conforme interface
    internalInterfaces = [ "eth0" ];
  };
}