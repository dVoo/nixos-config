{ inputs, config, lib, pkgs, pkgs-unstable, ... }:

{
  nixpkgs.config.allowUnfree = true;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # System identification
  time.timeZone = "Europe/Berlin";
  i18n.defaultLocale = "en_US.UTF-8";

  # Boot & Encryption with systemd-boot
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
   
  # OpenGL
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  # Xwayland
  programs.xwayland.enable = true;

  # Greeter
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd Hyprland";
        user = "greeter";
      };
    };
  };

  # Hyprland
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
    # package = inputs.hyprland.packages.${pkgs.system}.hyprland;
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
    mesa
  ];

  # User configuration
  users.users.daniel = {
    isNormalUser = true;
    home = "/home/daniel";
    createHome = true;
    shell = pkgs.fish;
    extraGroups = [ "wheel" "networkmanager" "video" "audio" "input" "render" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHx0lPZBTuVaaNU+oBRgnfLQQTwOks2OvKERgLntRD+2 daniel@xps"
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCvUrUJzhcnAAPxgs/BnFQlYDHd2SXRqAubRVNY1QqD9Xe9eRG2BuQoHjqyrKfK47bXKc+73pfBvC57Uf7dkQFK/izOElQtBQRJrveBIwL/34DfpGcmGPtPInypkN8vmcKdUqT51dJ8tI90t6+4yHE/pSk09Vlaq6a0877wiQm7/1Mvn2NFLy5bAbjA/jVMDTMD5j0ZWTyig6d82Y6Nw8VNUIwsHOBG+E3tBdEK2fSVpOJ7CjPLqdP29uAzemTgEnjJhiMRdxDN9Ril8FTGAQLQ+2e2LnqKbQj2pRwboNk0g/kVwNC2tdSv4+UHfWvtKrEdV2LN/hkhB+Mx8oFZ2Hn3 daniel@pc"
    ];
  };

  services.udev.packages = [ pkgs.libinput ];

  # SSH Server
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = true;
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
  system.stateVersion = "25.11";
}

