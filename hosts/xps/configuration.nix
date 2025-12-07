{ inputs, config, lib, pkgs, pkgs-unstable, ... }:

{
  imports = [
    ./hardware-configuration.nix 
    ./disko.nix
    ../../modules/common.nix
  ];
  # System identification
  networking.hostName = "xps";

  # CachyOS Kernel with gaming optimizations
  boot.kernelPackages = pkgs.linuxPackages_zen;

  # AMD GPU Configuration (RX6800)
  hardware.amdgpu.opencl.enable = true;
  hardware.amdgpu.initrd.enable = true;

  # Wayland
  environment.sessionVariables = {
    AMD_VULKAN_ICD = "RADV";
  };
}

