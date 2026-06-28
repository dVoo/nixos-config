{
  inputs,
  config,
  lib,
  pkgs,
  ...
}:

{
  # Use the default kernel on laptops — Zen/CachyOS are performance-tuned
  # and draw more power. The standard kernel is battery-friendly enough for
  # daily use on an Ultrabook.
  boot.kernelPackages = pkgs.linuxPackages;

  # Power management — power-profiles-daemon (PPD) is enabled in common.nix
  # for all hosts. Noctalia's PowerProfileService integrates with it via
  # Quickshell's UPower/PowerProfilesQml to provide the 3-profile
  # (PowerSaver/Balanced/Performance) UI. TLP was removed because it conflicts
  # with PPD (NixOS asserts mutual exclusivity).
  powerManagement = {
    enable = true;
    # powertop as a MONITOR only — PPD handles runtime power profiles
    powertop.enable = false;
  };

  # Battery charge thresholds — PPD does NOT manage these (TLP did via
  # START/STOP_CHARGE_THRESH). We set them directly via sysfs on boot.
  # `charge_type=Custom` is a kernel 6.11+ Dell requirement; older firmware
  # (e.g. XPS 13 9370) doesn't expose it, so the write is best-effort.
  systemd.services.battery-charge-threshold = {
    description = "Set battery charge thresholds (start 80, stop 85)";
    serviceConfig = {
      Type = "oneshot";
      User = "root";
      ExecStart = "${pkgs.bash}/bin/bash -c 'echo Custom > /sys/class/power_supply/BAT0/charge_type 2>/dev/null || true; echo 80 > /sys/class/power_supply/BAT0/charge_control_start_threshold; echo 85 > /sys/class/power_supply/BAT0/charge_control_end_threshold'";
    };
    wantedBy = [ "multi-user.target" ];
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

  boot = {
    # Better PCIe link power management on many laptops
    kernelParams = [
      "pcie_aspm.policy=powersave"
      "usbcore.autosuspend=2"       # USB devices suspend after 2s idle
    ];

    extraModprobeConfig = ''
      # Audio power saving
      options snd_hda_intel power_save=1

      # Wi‑Fi power saving (Intel iwlwifi — silently no-ops on non-Intel WiFi)
      options iwlwifi power_save=1 d0i3_disable=0 uapsd_disable=0
    '';

    kernel.sysctl = {
      "vm.dirty_writeback_centisecs" = 6000;
      "vm.laptop_mode" = 5;
    };
  };

  services.udev.extraRules = ''
    # Disable Wake‑on‑LAN for wired, enable Wi‑Fi power save
    ACTION=="add", SUBSYSTEM=="net", KERNEL=="eth*",  RUN+="${pkgs.ethtool}/bin/ethtool -s %k wol d"
    ACTION=="add", SUBSYSTEM=="net", KERNEL=="wlan*", RUN+="${pkgs.iw}/bin/iw dev %k set power_save on"
    ACTION=="add", SUBSYSTEM=="backlight", KERNEL=="intel_backlight", MODE="0664", GROUP="video"
  '';

  # Only run auto-upgrades when on AC power — no point burning battery on a nix build
  systemd.services.nixos-upgrade.serviceConfig.ConditionACPower = true;
}
