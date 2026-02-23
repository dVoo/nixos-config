{ inputs, config, lib, pkgs, pkgs-unstable, nixos-hardware, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./disko.nix
    ../../modules/common.nix
    ../../modules/gaming.nix
    nixos-hardware.nixosModules.common-cpu-amd
    nixos-hardware.nixosModules.common-cpu-amd-pstate
    nixos-hardware.nixosModules.common-gpu-amd
    nixos-hardware.nixosModules.common-pc-ssd
  ];
  # System identification
  networking.hostName = "pc";

  # AMD GPU Configuration (RX6800)
  hardware.amdgpu.opencl.enable = true;

  # Wayland
  environment.sessionVariables = {
    AMD_VULKAN_ICD = "RADV";
  };
}
