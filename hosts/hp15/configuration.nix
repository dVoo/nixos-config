{
  inputs,
  config,
  lib,
  pkgs,
  pkgs-unstable,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
    ./disko.nix
    ../../modules/common.nix
    ../../modules/notebook.nix
    ../../modules/gaming.nix
  ];
  # System identification
  networking.hostName = "hp15";

  # Power management
  services.thermald.enable = true;
  boot.kernelPackages = pkgs.linuxPackages_cachyos;
  boot.kernelParams = [ "pcie_aspm=off"  ];

  services.xserver.videoDrivers = [
    "modesetting"
    "nvidia"
  ];

  #Xbox Ctrl
  hardware.xpadneo.enable = true;

  hardware.graphics.extraPackages = with pkgs; [
    intel-media-driver
    vpl-gpu-rt
  ];

  # Realtek Fix
  networking.networkmanager.wifi.powersave = false;

  hardware.nvidia = {
    open = true;
    nvidiaSettings = true; # Enable NVIDIA settings menu
    package = config.boot.kernelPackages.nvidiaPackages.beta; # Use stable version

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

  environment.sessionVariables = {
    VDPAU_DRIVER = "va_gl";
    GBM_BACKEND = "mesa";
    __GLX_VENDOR_LIBRARY_NAME = "mesa";
  };
}
