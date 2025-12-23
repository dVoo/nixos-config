{
  inputs,
  config,
  lib,
  pkgs,
  pkgs-unstable,
  ...
}:

{
  # Enable NTSync
  boot.kernelModules = [ "ntsync" ];
  services.udev.extraRules = ''
    KERNEL=="ntsync", MODE="0644"
  '';

  # Mesa Unstable
  hardware.graphics.package = pkgs-unstable.mesa;
  hardware.graphics.package32 = pkgs-unstable.pkgsi686Linux.mesa;
  hardware.graphics.extraPackages = [ pkgs-unstable.mesa.opencl ];
    
  # Steam Gaming
  programs.steam = {
    enable = true;
    gamescopeSession.enable = true; # If you want the Deck-like session

    # Optimize download/extraction
    package = pkgs-unstable.steam.override {
      extraPkgs =
        pkgs: with pkgs-unstable; [
          gamemode
          mangohud
        ];
    };

    extraCompatPackages = with pkgs-unstable; [
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
          ${pkgs.libnotify}/bin/notify-send 'GameMode started' && \
          ${pkgs.systemd}/bin/systemctl --user stop swww-random-wallpaper.service && \
          ${pkgs.systemd}/bin/systemctl --user stop swww.service && \
          echo performance | sudo tee /sys/class/drm/card*/device/power_dpm_force_performance_level
        '';
        end = ''
          ${pkgs.libnotify}/bin/notify-send 'GameMode ended' && \
          ${pkgs.systemd}/bin/systemctl --user start swww.service && \
          ${pkgs.systemd}/bin/systemctl --user start swww-random-wallpaper.service && \
          echo auto | sudo tee /sys/class/drm/card*/device/power_dpm_force_performance_level
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
      ];
    }
  ];
}
