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

  # Chaotic mesa
  chaotic = {
    # Bleeding edge Mesa (OpenGL/Vulkan) from git
    mesa-git = {
      enable = true;
      extraPackages = [ pkgs.mesa_git.opencl ]; # Optional OpenCL support
    };

    # Valve's HDR-enabled Gamescope (if you use it)
    hdr = {
      enable = true;
      specialisation.enable = false; # Set to true if you want a separate boot entry
    };
  };

  # Steam Gaming
  programs.steam = {
    enable = true;
    gamescopeSession.enable = true; # If you want the Deck-like session

    # Optimize download/extraction
    package = pkgs.steam.override {
      extraPkgs =
        pkgs: with pkgs; [
          gamemode
          mangohud
        ];
    };

    extraCompatPackages = with pkgs; [
      inputs.chaotic.packages.${pkgs.stdenv.hostPlatform.system}.proton-cachyos
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
