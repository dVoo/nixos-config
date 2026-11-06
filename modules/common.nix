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
    trusted-users = [ "@wheel" ];
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
    "vm.max_map_count" = 2147483642; # Steam/Proton
    # zram (below) is the first swap device, so the kernel should prefer
    # compressing cold pages into it over dropping page cache. The previous
    # value of 10 does the opposite and left zram almost unused, which is why
    # the 32G encrypted swap partition was doing all the work. 100-180 is the
    # recommended range when zram is the primary swap; 150 leaves headroom.
    "vm.swappiness" = 150;
    # No swap read-ahead: zram has no seek latency, so prefetching whole
    # clusters only burns CPU and memory bandwidth.
    "vm.page-cluster" = 0;
    "net.core.default_qdisc" = "fq";
    "net.ipv4.tcp_congestion_control" = "bbr";
    "net.ipv4.tcp_fastopen" = 3;
    "kernel.nmi_watchdog" = 0;
    # Byte-based dirty limits instead of ratios: with 32G RAM the old
    # dirty_ratio=10 permitted ~3G of dirty pages, turning any large copy
    # into a multi-second writeback stall. (Removed net.core.somaxconn=1024,
    # which is below the modern default of 4096, and
    # kernel.sched_autogroup_enabled=1, which is already the default.)
    "vm.dirty_background_bytes" = 67108864; # 64 MiB
    "vm.dirty_bytes" = 268435456; # 256 MiB
  };

  # Firmware upgrades
  hardware.enableRedistributableFirmware = true;

  # Graphics
  hardware.graphics.enable = true;
  # (extraPackages is set per host: Intel media driver on the notebooks,
  # mesa.opencl + amdgpu on the desktop.)

  # Xwayland.
  #
  # These are two different implementations and both are needed:
  #   * Hyprland (kept as a fallback session, see modules/hyprland.nix) starts
  #     the classic `Xwayland` server itself, which is what
  #     programs.xwayland.enable installs and keeps in the system profile.
  #   * niri never launches Xwayland. Since 25.08 it integrates with
  #     xwayland-satellite out of the box: it exports DISPLAY, creates the
  #     X11 socket and spawns xwayland-satellite on demand, as long as
  #     xwayland-satellite >= 0.7 is on PATH (it is, via home.packages in
  #     modules/niri.nix). Do NOT add a spawn-at-startup for it — niri's
  #     automatic integration requires that it is not started manually.
  # Verify the niri path with:
  #   journalctl --user-unit=niri -b | grep 'listening on X11 socket'
  programs.xwayland.enable = true;

  # Greeter — noctalia-greeter on greetd; niri is the standard WM.
  # The nixpkgs module is the only greeter module enabled (upstream warns that
  # its own flake module uses different option paths and must not be mixed).
  # It sets greetd's default_session.command and its "greeter" user itself, so
  # the previous tuigreet block is gone rather than overridden.
  services.displayManager.noctalia-greeter = {
    enable = true;
    cursorTheme = {
      package = pkgs.bibata-cursors;
      name = "Bibata-Modern-Classic";
    };
    settings = {
      session.default = "niri";
      cursor.size = 24;
    };
  };

  # The greeter discovers sessions by scanning XDG data dirs, and it does not
  # inherit environment.sessionVariables (no PAM session), so niri's
  # wayland-sessions entry has to be linked into the system profile. niri is
  # already in environment.systemPackages via programs.niri.enable.
  environment.pathsToLink = [ "/share/wayland-sessions" ];

  # Gnome Keyring. The niri module already sets gnome.gnome-keyring.enable to
  # true with mkDefault (nixpkgs programs/wayland/niri.nix pulls in
  # wayland-session.nix), so only the greeter's PAM integration is needed here.
  security.pam.services.greetd.enableGnomeKeyring = true;

  # Niri — standard Wayland compositor for all hosts
  programs.niri.enable = true;

  # Zram - compressed RAM swap for faster memory reclaim. It is the
  # highest-priority swap device (100 > the disk partition's -2), so with
  # vm.swappiness raised to 150 cold anonymous pages land here first instead
  # of being pushed to the encrypted disk swap. memoryPercent is explicit
  # (50% of RAM = 15.5G on the 31G machines) rather than relying on the
  # option default.
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    priority = 100;
    memoryPercent = 50;
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

  # Bluetooth — Noctalia's panel provides its own Bluetooth applet, so we
  # don't enable blueman's separate tray widget.
  hardware.bluetooth.enable = true;

  # Flatpak for additional apps
  services.flatpak.enable = true;

  # Fish
  programs.fish.enable = true;

  # API keys — decrypted by agenix at boot (before any user session exists),
  # so home.sessionVariables (in home.nix) can `cat` them once without a
  # startup race. Paths default to ${age.secretsDir}/<name> (/run/agenix).
  # Recipients are the machines' SSH host keys (see secrets.nix), which live
  # on the root filesystem and are readable at boot — unlike ~/.ssh, which is
  # on the /home subvolume and not mounted yet when the activation runs.
  age.secrets.ollama-api-key = {
    file = ../secrets/ollama-api-key.age;
    owner = "daniel";
    mode = "0400";
  };
  age.secrets.openrouter-api-key = {
    file = ../secrets/openrouter-api-key.age;
    owner = "daniel";
    mode = "0400";
  };
  age.secrets.deepseek-api-key = {
    file = ../secrets/deepseek-api-key.age;
    owner = "daniel";
    mode = "0400";
  };
  age.secrets.opencode-api-key = {
    file = ../secrets/opencode-api-key.age;
    owner = "daniel";
    mode = "0400";
  };
  # The kubeconfig is a system secret for the same reason as the keys above:
  # host keys can decrypt it before any user session exists. It is consumed
  # through ~/.kube/config, a symlink created in home.nix.
  #
  # NOTE: secrets/weather-api-key.age is intentionally NOT declared here.
  # Noctalia 5.1's weather widget is keyless (its settings expose only
  # weather-unit/weather-refresh-interval/weather-effects, and the generated
  # ~/.config/noctalia/config.toml has no API-key field), so nothing consumed
  # this secret while it was still being decrypted into the home directory.
  # The .age file and its secrets.nix entry are kept so it can be re-added in
  # one line if a consumer appears — see secrets/README.md.
  age.secrets.kubeconfig = {
    file = ../secrets/kubeconfig.age;
    owner = "daniel";
    mode = "0400";
  };

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
    podman-compose
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

  # Authorization (security.polkit.enable is already set by the niri module,
  # see nixpkgs' programs/wayland/wayland-session.nix)
  services.dbus.enable = true;

  # Fonts.
  #
  # KEEP THIS LIST COMPLETE. google-fonts and the JetBrains/Droid nerd fonts are
  # used for daily Inkscape work, not just by the terminal and the bar. An
  # earlier cleanup pass removed them as "unreferenced by config" and had to be
  # reverted — the references are in the user's documents, so no amount of
  # grepping this repository can prove them unused.
  #   * nerd-fonts.fira-code              -> FiraCode Nerd Font / ... Mono (kitty, Noctalia)
  #   * nerd-fonts.iosevka                -> wide-fallback monospace
  #   * nerd-fonts.jetbrains-mono         -> Inkscape / design work
  #   * nerd-fonts.droid-sans-mono        -> Inkscape / design work
  #   * google-fonts                      -> Inkscape / design work
  #     (costs ~2.3 GiB of closure; accepted deliberately, do not "optimise" it
  #      away again)
  #   * dejavu_fonts                      -> also pulled in by
  #     enableDefaultPackages, kept explicit so it cannot vanish by accident
  fonts.enableDefaultPackages = true;
  fonts.packages = with pkgs; [
    nerd-fonts.iosevka
    nerd-fonts.jetbrains-mono
    nerd-fonts.fira-code
    nerd-fonts.droid-sans-mono
    dejavu_fonts
    google-fonts
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
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOmu3QXj2b0OkbKPCxS+gIWUXvaI0hq/VX1xa3anlal6 daniel@yoga"
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

  # Garbage Collection - Automatic cleanup. `--delete-older-than 7d` with a
  # weekly timer meant almost every generation became collectable within a
  # week, so rebuilding after a short break re-downloaded store paths.
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  # Bound the number of boot entries. The ESP is only 512M (modules/disko.nix)
  # and systemd-boot keeps every generation, so without a limit a busy
  # rebuild history can fill /boot and break the next boot.
  boot.loader.systemd-boot.configurationLimit = 10;

  # Locale
  i18n.supportedLocales = [ "en_US.UTF-8/UTF-8" ];

  # Periodic TRIM on every host. Continuous discards were removed from the
  # mount options in modules/disko.nix, so this timer is now the only thing
  # that discards free blocks (including on /boot, which is a vfat partition).
  services.fstrim.enable = true;

  # Services
  services.udisks2.enable = true;
  services.gvfs.enable = true;

  nixpkgs.overlays = [
    (final: prev: {
      udiskie = prev.udiskie.overrideAttrs (oldAttrs: {
        doCheck = false; # Überspringt die fehlerhafte Test-Phase
      });
    })
  ];

  # AusweisApp is a local-only client: it exposes TCP 24727 for the local
  # browser/reader to talk to, and loopback is already allowed by the
  # firewall. The previous openFirewall = true punched that port open on
  # every interface of every host.

  # Controllers and Steam udev rules moved to modules/gaming.nix — they are
  # desktop-only and the notebooks never had a use for them.

  # System state version - do not change!
  system.stateVersion = "25.11";
}
