{ inputs, config, lib, pkgs, pkgs-unstable, ... }:

{
  imports = [
    ./hardware-configuration.nix 
    ./disko.nix
    ../../modules/common.nix
    ../../modules/gaming.nix
  ];
  # System identification
  networking.hostName = "pc";

  # CachyOS Kernel with gaming optimizations
  boot.kernelPackages = pkgs.linuxPackages_cachyos;

  # AMD GPU Configuration (RX6800)
  hardware.amdgpu.opencl.enable = true;
  hardware.amdgpu.initrd.enable = true;

  # Wayland
  environment.sessionVariables = {
    AMD_VULKAN_ICD = "RADV";
  };
}

