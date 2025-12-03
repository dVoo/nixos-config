{ config, lib, pkgs, pkgs-unstable, ... }:

{
  imports = [ ./hardware-configuration.nix ];

  # System identification
  networking.hostName = "pc";
  time.timeZone = "Europe/Berlin";
  i18n.defaultLocale = "en_US.UTF-8";

  # Boot & Encryption with systemd-boot
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  
  # LUKS encryption - UPDATE UUID AFTER INSTALLATION
  boot.initrd.luks.devices = {
    "crypt" = {
      device = "/dev/disk/by-uuid/PASTE-YOUR-LUKS-UUID-HERE";
      preLVM = true;
    };
    "swap" = {
      device = "/dev/disks/by-uuid/SWAP-LUKS-UUID"
    }
  };

  # Swap
  swapDevices = [{
    device = "/dev/mapper/swap";
  }];

  # Hibernation
  powerManagement.enable = true;
  services.logind.extraConfig = ''
    HandleHibernateKey=hibernate
    HibernateMode=hibernate
  '';

  # CachyOS Kernel with gaming optimizations
  boot.kernelPackages = pkgs.linuxPackages_cachyos;

  # AMD CPU microcode
  hardware.cpu.amd.updateMicrocode = true;

  # AMD GPU Configuration (RX6800)
  hardware.amdgpu.enable = true;
  hardware.amdgpu.opencl.enable = true;
  hardware.amdgpu.initrd.enable = true;

  # OpenGL
  hardware.opengl.enable = true;
  hardware.opengl.driSupport = true;
  hardware.opengl.driSupport32Bit = true;

  # Wayland
  environment.sessionVariables.WAYLAND_DISPLAY = "wayland-1";
  environment.sessionVariables.GBM_BACKEND = "amdgpu";

  # Xwayland
  programs.xwayland.enable = true;

  # Hyprland
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
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

  # System packages
  environment.systemPackages = with pkgs; [
    steam
    vim
    wget
    curl
    firefox
    vscode
    git
    mangohud
    gamescope
    protonup-qt
    vulkan-tools
    clinfo
  ];

  # User configuration
  users.users.gaming = {
    isNormalUser = true;
    home = "/home/gaming";
    createHome = true;
    shell = lib.mkDefault pkgs.bash;
    extraGroups = [ "wheel" "video" "audio" "input" ];
    # SSH Public Key - ADD YOUR PUBLIC KEY HERE
    openssh.authorizedKeys.keys = [
      # "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI... your-key-name"
    ];
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

