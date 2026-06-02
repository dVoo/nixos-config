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

  powerManagement = {
    enable = true;
    # powertop as a MONITOR only — TLP handles all runtime power saving
    powertop.enable = false;
  };

  # TLP — handles AC/battery-aware power saving (auto-enabled by
  # nixos-hardware laptop module now that power-profiles-daemon is gone).
  # We configure it explicitly for Dell battery charging thresholds and
  # to ensure consistent settings across AC/battery transitions.
  services.tlp = {
    enable = true;
    settings = {
      # Dell battery longevity: stop charging at 85%, resume at 80%
      START_CHARGE_THRESH_BAT0 = "80";
      STOP_CHARGE_THRESH_BAT0  = "85";

      # CPU — powersave governor on battery
      CPU_BATTERY_MODE        = "powersave";
      CPU_MAX_PERF_ON_BAT     = "80";

      # Aggressive power saving on battery
      WIFI_PWR_ON_BAT         = "on";
      PCIE_ASPM_ON_BAT        = "powersave";
      SATA_LINKPWR_ON_BAT     = "min_power";
      USB_AUTOSUSPEND         = "1";
      SOUND_POWER_SAVE_ON_BAT = "1";
      RUNTIME_PM_ON_BAT       = "auto";
      NMI_WATCHDOG            = "0";
    };
  };

  services.upower.enable = true;
  services.logind.settings.Login = {
    HandleLidSwitch = "suspend";
    HandleLidSwitchExternalPower = "suspend";
    HandleLidSwitchDocked = "ignore";
  };

  environment.systemPackages = with pkgs; [
    upower
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

      # Wi‑Fi power saving (Intel example)
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
