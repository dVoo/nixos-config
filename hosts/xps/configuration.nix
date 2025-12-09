{ inputs, config, lib, pkgs, pkgs-unstable, ... }:

{
  imports = [
    ./hardware-configuration.nix 
    ./disko.nix
    ../../modules/common.nix
    ../../modules/notebook.nix
  ];
  # System identification
  networking.hostName = "xps";

  # CachyOS Kernel with gaming optimizations
  boot.kernelPackages = pkgs.linuxPackages_zen;
}

