{ inputs, config, lib, pkgs, pkgs-unstable, ... }:

{
  nixpkgs.config.allowUnfree = true;
  imports = [ ./hardware-configuration.nix ];

  # System identification
  networking.hostName = "pc";
  time.timeZone = "Europe/Berlin";
  i18n.defaultLocale = "en_US.UTF-8";

  # Boot & Encryption with systemd-boot
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
   
  # Hibernation
  # services.logind.settings = {
  #   HandlePowerKey = "suspend";
  #   IdleAction = "suspend";
  #   IdleActionSec = "30min";
  # };

  # CachyOS Kernel with gaming optimizations
  boot.kernelPackages = pkgs.linuxPackages_zen;

  # AMD GPU Configuration (RX6800)
  hardware.amdgpu.opencl.enable = true;
  hardware.amdgpu.initrd.enable = true;

  # OpenGL
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  # Wayland
  environment.sessionVariables.WAYLAND_DISPLAY = "wayland-1";
  environment.sessionVariables.GBM_BACKEND = "amdgpu";

  # Xwayland
  programs.xwayland.enable = true;

  # Hyprland
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
    package = inputs.hyprland.packages.${pkgs.system}.hyprland;
  };

  # PipeWire Audio
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };

  # Bluetooth
  hardware.bluetooth.enable = true;
  services.blueman.enable = true;

  # Steam Gaming
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
    extraCompatPackages = with pkgs; [
      proton-ge-bin
    ];
  };

  # Flatpak for additional apps
  services.flatpak.enable = true;

  # Fish
  programs.fish.enable = true;
  environment.variables.EDITOR = "hx";

  # System packages
  environment.systemPackages = with pkgs; [
    steam
    helix
    wget
    curl
    git
    mangohud
    gamescope
    protonup-qt
    vulkan-tools
    clinfo
  ];

  # User configuration
  users.users.daniel = {
    isNormalUser = true;
    home = "/home/daniel";
    createHome = true;
    shell = pkgs.fish;
    extraGroups = [ "wheel" "video" "audio" "input" ];
  };

  # SSH Server
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
      PubkeyAuthentication = true;
    };
  };

  # Network
  networking.networkmanager.enable = true;

  # Garbage Collection - Automatic cleanup
  nix = {
    settings.auto-optimise-store = true;
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 7d";
    };
  };

  # Locale
  i18n.supportedLocales = ["en_US.UTF-8/UTF-8"];

  # System state version - do not change!
  system.stateVersion = "24.11";
}

