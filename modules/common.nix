{
  inputs,
  config,
  lib,
  pkgs,
  pkgs-unstable,
  ...
}:

{
  nixpkgs.config.allowUnfree = true;
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # System identification
  time.timeZone = "Europe/Berlin";
  i18n.defaultLocale = "en_US.UTF-8";

  # Boot & Encryption with systemd-boot
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  powerManagement = {
    cpuFreqGovernor = "schedutil";
  };

  services.power-profiles-daemon.enable = true;

  #
  boot.kernel.sysctl = {
    "vm.max_map_count" = 2147483642;
  };

  # Firmware upgrades
  hardware.enableRedistributableFirmware = true;
  hardware.enableAllFirmware = true;

  # Graphics
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
    withUWSM = true;
    xwayland.enable = true;
  };

  # PipeWire Audio
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;

    # Add this config to tune latency
    extraConfig.pipewire."92-low-latency" = {
      "context.properties" = {
        "default.clock.rate" = 48000;
        "default.clock.quantum" = 512;
        "default.clock.min-quantum" = 512;
        "default.clock.max-quantum" = 2048;
      };
    };
  };

  # Bluetooth
  hardware.bluetooth.enable = true;
  services.blueman.enable = true;

  # Flatpak for additional apps
  services.flatpak.enable = true;

  # Fish
  programs.fish.enable = true;
  environment.variables.EDITOR = "hx";

  # System packages
  environment.systemPackages = with pkgs; [
    helix
    wget
    curl
    git
    rsync
    mangohud
    gamescope
    vulkan-tools
    clinfo
    python3
    uv
  ];

  # Authorization
  security.polkit.enable = true;
  services.dbus.enable = true;

  # Fonts
  fonts.packages = with pkgs; [
    nerd-fonts.iosevka
    nerd-fonts.jetbrains-mono
    nerd-fonts.fira-code
    nerd-fonts.droid-sans-mono
  ];

  # User configuration
  users.users.daniel = {
    isNormalUser = true;
    home = "/home/daniel";
    createHome = true;
    shell = pkgs.fish;
    extraGroups = [
      "wheel"
      "networkmanager"
      "video"
      "audio"
      "input"
      "render"
    ];
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
  i18n.supportedLocales = [ "en_US.UTF-8/UTF-8" ];

  # Services
  services.udisks2.enable = true;
  services.gvfs.enable = true;

  # System state version - do not change!
  system.stateVersion = "25.11";
}
