{
  inputs,
  config,
  lib,
  pkgs,
  nixos-hardware,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/disko.nix
    ../../modules/common.nix
    ../../modules/notebook.nix
    nixos-hardware.nixosModules.dell-xps-13-9370
    nixos-hardware.nixosModules.common-pc-ssd
  ];
  # System identification
  networking.hostName = "xps";

  environment.sessionVariables = {
    LIBVA_DRIVER_NAME = "iHD";
    NIXOS_OZONE_WL = "1";
  };

  hardware.graphics.extraPackages = [ pkgs.intel-media-driver ];
}
