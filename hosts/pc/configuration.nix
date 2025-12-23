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

  boot.kernelPackages = pkgs.linuxPackages_zen;

  # AMD GPU Configuration (RX6800)
  hardware.amdgpu.opencl.enable = true;
  hardware.amdgpu.initrd.enable = true;

  # Wayland
  environment.sessionVariables = {
    AMD_VULKAN_ICD = "RADV";
  };
}

