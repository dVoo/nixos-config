{
  inputs,
  config,
  lib,
  pkgs,
  ...
}:

{
  boot.kernelPackages = pkgs.linuxPackages;

  # TLP replaces power-profiles-daemon on notebooks. It conflicts with ppd,
  # so ppd is only enabled on the desktop host (pc) now. tlp-pd exposes a
  # ppd-compatible D-Bus interface (net.hadess.PowerProfiles), so Noctalia's
  # power_profile widget works on notebooks too — manual profile switching
  # (PowerSaver/Balanced/Performance) maps to TLP's platform profiles.
  services.tlp = {
    enable = true;
    pd.enable = true;
    settings = {
      # Battery charge thresholds (ThinkPads with BAT0 charge_control sysfs).
      # The Dell XPS 13 9370 lacks these sysfs files; TLP detects this and
      # skips the writes, so it's safe to set them globally here.
      START_CHARGE_THRESH_BAT0 = 80;
      STOP_CHARGE_THRESH_BAT0 = 85;

      # Audio power saving (replaces the old snd_hda_intel modprobe option).
      SOUND_POWER_SAVE_ON_AC = 1;
      SOUND_POWER_SAVE_ON_BAT = 1;
      SOUND_POWER_SAVE_CONTROLLER = "Y";

      # PCIe active state power management.
      PCIE_ASPM_ON_AC = "default";
      PCIE_ASPM_ON_BAT = "powersupersave";

      # Wi-Fi power saving (replaces the old wlan* udev rule).
      WIFI_PWR_ON_AC = "on";
      WIFI_PWR_ON_BAT = "on";

      # Disable Wake-on-LAN (replaces the old eth* udev rule).
      WOL_DISABLE = "Y";

      # Disk spindown / NVMe power state.
      DISK_DEVICES = "nvme0n1";
      DISK_APM_LEVEL_ON_AC = 254;
      DISK_APM_LEVEL_ON_BAT = 254; # NVMe ignores APM; TLP still applies autosuspend

      # CPU scaling governor is managed by the kernel/intel_pstate driver.
      CPU_ENERGY_PERF_POLICY_ON_AC = "balance_performance";
      CPU_ENERGY_PERF_POLICY_ON_BAT = "balance_power";

      # Platform profile (replaces ppd's PowerSaver/Balanced/Performance).
      PLATFORM_PROFILE_ON_AC = "balanced";
      PLATFORM_PROFILE_ON_BAT = "low-power";

      # Laptop-mode-style writeback (replaces the old vm.laptop_mode sysctl).
      # MAX_LOST_WORK_SECS_ON_BAT=60 preserves the old dirty_writeback_centisecs=6000.
      MAX_LOST_WORK_SECS_ON_BAT = 60;
      NMI_WATCHDOG = "off";
    };
  };

  services.upower.enable = true;
  services.logind.settings.Login = {
    HandleLidSwitch = "suspend";
    HandleLidSwitchExternalPower = "suspend";
    HandleLidSwitchDocked = "ignore";
  };

  environment.systemPackages = with pkgs; [
    powertop # handy CLI monitor/tuner
  ];

  services.udev.packages = [ pkgs.brightnessctl ];

  services.udev.extraRules = ''
    ACTION=="add|change", SUBSYSTEM=="backlight", KERNEL=="intel_backlight", MODE="0664", GROUP="video"

    # Matches standard ThinkPad sensors (Synaptics 06cb, Goodix, etc.) via product strings & vendor ID
    ACTION=="add|change", SUBSYSTEM=="usb", ATTRS{product}=="*Fingerprint*", ATTR{power/wakeup}="disabled", ATTR{power/control}="auto"
    ACTION=="add|change", SUBSYSTEM=="usb", ATTRS{product}=="*FingerPrint*", ATTR{power/wakeup}="disabled", ATTR{power/control}="auto"
    ACTION=="add|change", SUBSYSTEM=="usb", ATTRS{idVendor}=="06cb", ATTR{power/wakeup}="disabled", ATTR{power/control}="auto"
  '';

  # ProtonVPN (NetworkManager WireGuard connection, iface "proton0", MTU 1420)
  # suffers from PMTUD blackholing: ICMP "fragmentation needed" is dropped
  # somewhere along the path, so the kernel never learns the real path MTU
  # (~1328, verified via `ping -M do -s 1300`). Small packets (ping, tiny
  # HTTP responses) pass; large ones (TLS handshakes, HTTPS page loads)
  # silently vanish.
  #
  # --clamp-mss-to-pmtu is useless here because it uses the interface MTU
  # (1420 → MSS 1380), which is still above the real path MTU. We use an
  # explicit --set-mss 1280 (path MTU 1320, safely below the verified 1328)
  # so TCP segments fit through the tunnel regardless of PMTUD.
  #
  # Both directions must be clamped: outbound SYN (client's MSS) via
  # POSTROUTING, and inbound SYN-ACK (server's MSS) via PREROUTING. FORWARD
  # rules are omitted — the notebook is the endpoint, not a router.
  #
  # IPv6 is the actual trap: ProtonVPN routes IPv6 default traffic through
  # "ipv6leakintrf0" (a leak-protection dummy iface, MTU 1500) and the real
  # path MTU there is also ~1328. curl/browsers try IPv6 first, so the TLS
  # ClientHello (1555 bytes) is silently dropped while IPv4 HTTPS works.
  # The same TCPMSS rules must be applied via ip6tables for both interfaces.
  networking.firewall.extraCommands = ''
    iptables -t mangle -A POSTROUTING -o proton0 -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --set-mss 1280
    iptables -t mangle -A PREROUTING -i proton0 -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --set-mss 1280
    ip6tables -t mangle -A POSTROUTING -o proton0 -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --set-mss 1280
    ip6tables -t mangle -A PREROUTING -i proton0 -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --set-mss 1280
    ip6tables -t mangle -A POSTROUTING -o ipv6leakintrf0 -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --set-mss 1280
    ip6tables -t mangle -A PREROUTING -i ipv6leakintrf0 -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --set-mss 1280
  '';
}