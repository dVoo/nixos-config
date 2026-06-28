{
  inputs,
  config,
  lib,
  pkgs,
  ...
}:

{
  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    auto-optimise-store = true;
    extra-substituters = [ "https://noctalia.cachix.org" ];
    extra-trusted-public-keys = [
      "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
    ];
  };

  nixpkgs.config.allowUnfree = true;

  # System identification
  time.timeZone = "Europe/Berlin";
  i18n.defaultLocale = "en_US.UTF-8";

  # Boot & Encryption with systemd-boot
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  programs.nix-ld.enable = true;

  boot.kernel.sysctl = {
    "vm.max_map_count" = 2147483642;
    "vm.swappiness" = 10;
    "kernel.sched_autogroup_enabled" = 1;
    "net.core.default_qdisc" = "fq";
    "net.ipv4.tcp_congestion_control" = "bbr";
    "net.core.somaxconn" = 1024;
    "net.ipv4.tcp_fastopen" = 3;
    "kernel.nmi_watchdog" = 0;
    "vm.dirty_background_ratio" = 5;
    "vm.dirty_ratio" = 10;
  };

  # Firmware upgrades
  hardware.enableRedistributableFirmware = true;

  # Graphics
  hardware.graphics = {
    enable = true;
    extraPackages = [ ];
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

  # Gnome Keyring
  services.gnome.gnome-keyring.enable = true;
  security.pam.services.greetd.enableGnomeKeyring = true;

  # Hyprland
  programs.hyprland = {
    enable = true;
    withUWSM = true;
    xwayland.enable = true;
  };

  # Zram - compressed RAM swap for faster memory reclaim
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    priority = 100;
  };

  # PipeWire Audio
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
  };

  # Bluetooth
  hardware.bluetooth.enable = true;
  services.blueman.enable = true;

  # Power profiles — enables Noctalia's power profile UI (PowerSaver/Balanced/
  # Performance). Works on AMD (amd-pstate) and Intel (intel_pstate). thermald
  # is enabled per-host on Intel notebooks that need active thermal management.
  services.power-profiles-daemon.enable = true;

  # Flatpak for additional apps
  services.flatpak.enable = true;

  # Fish
  programs.fish.enable = true;

  # System packages
  environment.systemPackages = with pkgs; [
    wget
    curl
    git
    unzip
    rsync
    clinfo
    python3
    uv
    qemu
  ];

  # Podman
  virtualisation = {
    containers.enable = true;
    podman = {
      enable = true;
      dockerCompat = true;
      defaultNetwork.settings.dns_enabled = true; # Required for containers under podman-compose to be able to talk to each other.
    };
  };

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
      "podman"
      "realtime"
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
      PasswordAuthentication = false;
      PubkeyAuthentication = true;
    };
  };

  # Network
  networking.networkmanager.enable = true;

  # Garbage Collection - Automatic cleanup
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 7d";
  };

  # Locale
  i18n.supportedLocales = [ "en_US.UTF-8/UTF-8" ];

  # Services
  services.udisks2.enable = true;
  services.gvfs.enable = true;

  # Open AusweisApp port 24727
  programs.ausweisapp.openFirewall = true;

  # Controllers
  hardware.xpadneo.enable = true;
  hardware.steam-hardware.enable = true;
  boot.kernelModules = [
    "uinput"
    "tcp_bbr"
  ];

  # System state version - do not change!
  system.stateVersion = "25.11";
}
