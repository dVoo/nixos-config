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
  services.thermald.enable = true;

  hardware.graphics.extraPackages = with pkgs; [
    intel-media-driver
    vpl-gpu-rt
  ];

  boot.kernelPackages = pkgs.linuxPackages_zen;

  environment.sessionVariables = {
    LIBVA_DRIVER_NAME = "iHD";
    NIXOS_OZONE_WL = "1";
  };
}

