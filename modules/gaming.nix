{ inputs, config, lib, pkgs, pkgs-unstable, ... }:

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
      extraPkgs = pkgs: with pkgs; [
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
      };
      # Auto-apply optimizations when GameMode starts
      custom = {
        start = "${pkgs.libnotify}/bin/notify-send 'GameMode started'";
        end = "${pkgs.libnotify}/bin/notify-send 'GameMode ended'";
      };
    };
  };
}
