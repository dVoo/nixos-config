{ inputs, config, lib, pkgs, nixos-hardware, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/disko.nix
    ../../modules/common.nix
    ../../modules/notebook.nix
    nixos-hardware.nixosModules.lenovo-thinkpad-x1-yoga-7th-gen
  ];

  # System identification
  networking.hostName = "yoga";

  # Alder Lake-U benefits from thermald for thermal/throttling management
  services.thermald.enable = true;

  # Periodic SSD trim on top of the mount-level discard options
  services.fstrim.enable = true;

  environment.sessionVariables = {
    LIBVA_DRIVER_NAME = "iHD";
    NIXOS_OZONE_WL = "1";
  };
}