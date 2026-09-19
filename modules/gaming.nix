{
  inputs,
  config,
  lib,
  pkgs,
  ...
}:

{
  # Controllers, Steam udev rules and the uinput module are desktop-only
  # concerns (moved here from modules/common.nix, which applied them to the
  # notebooks as well). tcp_bbr was listed there too but is built into the
  # kernel and only needs the sysctl, which common.nix sets.
  hardware.xpadneo.enable = true;
  hardware.steam-hardware.enable = true;

  # uinput is required by xpadneo.
  # ntsync must be loaded explicitly: it registers a misc device with a
  # dynamic minor, so there is no MODULE_ALIAS_MISCDEV for udev to autoload it
  # from.
  # NOTE: these have to live in a single list. Two separate
  # `boot.kernelModules = [...]` assignments at the same level are a hard Nix
  # error ("attribute 'boot.kernelModules' already defined"), unlike a dotted
  # path merged into an existing attrset literal.
  boot.kernelModules = [
    "uinput"
    "ntsync"
  ];
  # /dev/ntsync is world-writable (0666) in the driver itself since Linux
  # 6.14. The previous MODE="0644" here actively *removed* the write access
  # that Proton's ntsync path needs (0644 root:root = read-only for the user).
  # Match the kernel's own permissions.
  services.udev.extraRules = ''
    KERNEL=="ntsync", MODE="0666"
  '';

  # 32-bit drivers are required for Steam/Proton.
  hardware.graphics.enable32Bit = true;
  # package/package32 are no longer set: they were pinned to exactly the
  # nixpkgs defaults (mkDefault pkgs.mesa / pkgsi686Linux.mesa).
  #
  # extraPackages is empty on purpose. The pc enables
  # hardware.amdgpu.opencl (hosts/pc/configuration.nix), which already
  # registers the ROCm OpenCL ICD; adding pkgs.mesa.opencl here registered a
  # *second* ICD (Clover) and applications that happen to pick it lose most
  # of the GPU's OpenCL throughput. Verify with `clinfo -l`: the ROCm
  # platform should be the only one listed.

  # Gaming packages
  environment.systemPackages = with pkgs; [
    mangohud
    gamescope
    vulkan-tools
  ];

  # Steam Gaming
  programs.steam = {
    enable = true;
    gamescopeSession.enable = false;

    # Optimize download/extraction
    package = pkgs.steam.override {
      extraPkgs =
        pkgs: with pkgs; [
          gamemode
          mangohud
        ];
    };

    extraCompatPackages = with pkgs; [
      proton-ge-bin
    ];
  };

  # Gamemode
  programs.gamemode = {
    enable = true;
    settings = {
      general = {
        renice = 10;
        inhibit_screensaver = 1;
        softrealtime = "auto";
        reaper_freq = 5;
        desiredgov = "performance";
      };
      # Auto-apply optimizations when GameMode starts.
      #
      # Only the AMD DPM knob is touched now. The old /sys/block/{nvme,sd}*
      # scheduler writes were worse than pointless: no SATA device exists on
      # either host (so the sd* loops and their sudo rules were dead), and the
      # "restore" in `end` actively set NVMe to mq-deadline instead of leaving
      # the kernel's default `none`. The DPM level is saved first so `end`
      # restores whatever was set rather than hardcoding "auto".
      custom = {
        start = ''
          dir="''${XDG_RUNTIME_DIR:-/tmp}"
          if [ -r /sys/class/drm/card0/device/power_dpm_force_performance_level ]; then
            cat /sys/class/drm/card0/device/power_dpm_force_performance_level > "$dir/gamemode-dpm-level" || true
            echo performance | sudo tee /sys/class/drm/card0/device/power_dpm_force_performance_level >/dev/null
          fi
        '';
        end = ''
          dir="''${XDG_RUNTIME_DIR:-/tmp}"
          level="$(cat "$dir/gamemode-dpm-level" 2>/dev/null || echo auto)"
          if [ -r /sys/class/drm/card0/device/power_dpm_force_performance_level ]; then
            echo "$level" | sudo tee /sys/class/drm/card0/device/power_dpm_force_performance_level >/dev/null
          fi
        '';
      };
    };
  };

  security.sudo.extraRules = [
    {
      users = [ "daniel" ];
      # Only the AMD DPM override is needed: GameMode runs as the user and
      # writes the sysfs knob through `tee`. The block-scheduler rules were
      # dropped together with the writes they used to authorize. The path is
      # spelled out instead of using card* so the rule cannot be matched
      # against an arbitrary card.
      commands = [
        {
          command = "/run/current-system/sw/bin/tee /sys/class/drm/card0/device/power_dpm_force_performance_level";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];
}
