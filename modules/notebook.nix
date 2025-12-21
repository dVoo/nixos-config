{
  inputs,
  config,
  lib,
  pkgs,
  pkgs-unstable,
  ...
}:

{
  powerManagement = {
    enable = true;
    powertop.enable = true; # enables powertop and its autotune
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
    kernelParams = [ "pcie_aspm.policy=powersave" ];

    extraModprobeConfig = ''
      # Audio power saving
      options snd_hda_intel power_save=1

      # Wi‑Fi power saving (Intel example)
      options iwlwifi power_save=1 d0i3_disable=0 uapsd_disable=0
    '';

    kernel.sysctl = {
      "kernel.nmi_watchdog" = 0;
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
}
