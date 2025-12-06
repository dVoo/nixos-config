{ inputs, config, lib, pkgs, pkgs-unstable, ... }:

{
  imports = [
    ./hardware-configuration.nix 
    ./disko.nix
    ../../modules/common.nix
  ];
  # System identification
  networking.hostName = "hp15";

  # CachyOS Kernel with gaming optimizations
  boot.kernelPackages = pkgs.linuxPackages_zen;

  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = true; # Enable if needed
    nvidiaSettings = true;          # Enable NVIDIA settings menu
    package = config.boot.kernelPackages.nvidiaPackages.stable;  # Use stable version
  };
}

