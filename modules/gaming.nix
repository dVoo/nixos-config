{
  inputs,
  config,
  lib,
  pkgs,
  ...
}:

{
  # Enable NTSync
  boot.kernelModules = [ "ntsync" ];
  services.udev.extraRules = ''
    KERNEL=="ntsync", MODE="0644"
  '';

  # Mesa
  hardware.graphics.package = pkgs.mesa;
  hardware.graphics.package32 = pkgs.pkgsi686Linux.mesa;
  hardware.graphics.enable32Bit = true;
  hardware.graphics.extraPackages = [ pkgs.mesa.opencl ];

  # Gaming packages
  environment.systemPackages = with pkgs; [
    mangohud
    gamescope
    vulkan-tools
  ];

  # Steam Gaming
  programs.steam = {
    enable = true;
    gamescopeSession.enable = false;

    # Optimize download/extraction
    package = pkgs.steam.override {
      extraPkgs =
        pkgs: with pkgs; [
          gamemode
          mangohud
        ];
    };

    extraCompatPackages = with pkgs; [
      proton-ge-bin
    ];
  };

  # Gamemode
  programs.gamemode = {
    enable = true;
    settings = {
      general = {
        renice = 10;
        inhibit_screensaver = 1;
        softrealtime = "auto";
        reaper_freq = 5;
        desiredgov = "performance";
      };
      # Auto-apply optimizations when GameMode starts
      custom = {
        start = ''
          echo performance | sudo tee /sys/class/drm/card*/device/power_dpm_force_performance_level && \
          for dev in /sys/block/nvme*; do echo none | sudo tee "$dev/queue/scheduler"; done && \
          for dev in /sys/block/sd*; do echo bfq | sudo tee "$dev/queue/scheduler"; done
        '';
        end = ''
          echo auto | sudo tee /sys/class/drm/card*/device/power_dpm_force_performance_level && \
          for dev in /sys/block/nvme*; do echo mq-deadline | sudo tee "$dev/queue/scheduler"; done && \
          for dev in /sys/block/sd*; do echo bfq | sudo tee "$dev/queue/scheduler"; done
        '';
      };
    };
  };

  security.sudo.extraRules = [
    {
      users = [ "daniel" ];
      commands = [
        {
          command = "/run/current-system/sw/bin/tee /sys/class/drm/card*/device/power_dpm_force_performance_level";
          options = [ "NOPASSWD" ];
        }
        {
          command = "/run/current-system/sw/bin/tee /sys/block/nvme*/queue/scheduler";
          options = [ "NOPASSWD" ];
        }
        {
          command = "/run/current-system/sw/bin/tee /sys/block/sd*/queue/scheduler";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];
}
