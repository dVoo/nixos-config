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
    ../../modules/gaming.nix
    nixos-hardware.nixosModules.common-cpu-intel
    nixos-hardware.nixosModules.common-gpu-nvidia
    nixos-hardware.nixosModules.common-pc-laptop
    nixos-hardware.nixosModules.common-pc-ssd
  ];
  # System identification
  networking.hostName = "hp15";

  # Power management
  services.thermald.enable = true;
  boot.kernelParams = [ "pcie_aspm=off" ];

  services.xserver.videoDrivers = [
    "modesetting"
    "nvidia"
  ];

  # CachyOS
  nix.settings.extra-substituters = [
    "https://attic.xuyh0120.win/lantian"
    "https://cache.garnix.io"
  ];
  nix.settings.extra-trusted-public-keys = [
    "lantian:EeAUQ+W+6r7EtwnmYjeVwx5kOGEBpjlBfPlzGlTNvHc="
    "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="
  ];
  boot.initrd.luks.cryptoModules = [
    "aes"
    "blowfish"
    "twofish"
    "serpent"
    "cbc"
    "xts"
    "lrw"
    "sha1"
    "sha256"
    "sha512"
    "af_alg"
    "algif_skcipher"
  ];
  nixpkgs.overlays = [ inputs.nix-cachyos-kernel.overlays.default ];
  boot.kernelPackages = lib.mkForce pkgs.cachyosKernels."linuxPackages-cachyos-latest-x86_64-v3";

  # Realtek Fix
  networking.networkmanager.wifi.powersave = false;

  hardware.nvidia = {
    open = true;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.beta;

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
