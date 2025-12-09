{ inputs, config, lib, pkgs, pkgs-unstable, ... }:

{
  imports = [
    ./hardware-configuration.nix 
    ./disko.nix
    ../../modules/common.nix
    ../../modules/gaming.nix
  ];
  # System identification
  networking.hostName = "hp15";

  # CachyOS Kernel with gaming optimizations
  boot.kernelPackages = pkgs.linuxPackages_zen;

  # Power management
  services.thermald.enable = true;
  services.auto-cpufreq.enable = true;
  services.auto-cpufreq.settings = {
    battery = {
      governor = "powersave";
      turbo = "auto";
    };
    charger = {
      governor = "performance";
      turbo = "auto";
    };
  };
  services.power-profiles-daemon.enable = false; 

  hardware.nvidia = {
    modesetting.enable = true;
    open = false;
    nvidiaSettings = true;          # Enable NVIDIA settings menu
    package = config.boot.kernelPackages.nvidiaPackages.stable;  # Use stable version

    powerManagement.enable = true;
    powerManagement.finegrained = true;

    # Optimus / Hybrid Graphics
    prime = {
      offload = {
        enable = true;
        enableOffloadCmd = true;
      };
      
      intelBusId = "PCI:0:2:0";
      nvidiaBusId = "PCI:1:0:0";
    };
  };
}

