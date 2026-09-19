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
    ./disko.nix
    ../../modules/common.nix
    ../../modules/gaming.nix
    nixos-hardware.nixosModules.common-cpu-amd
    nixos-hardware.nixosModules.common-cpu-amd-pstate
    nixos-hardware.nixosModules.common-gpu-amd
    nixos-hardware.nixosModules.common-pc-ssd
  ];

  # CachyOS
  nix.settings.extra-substituters = [
    # "https://attic.xuyh0120.win/lantian"
    "https://cache.garnix.io"
  ];
  nix.settings.extra-trusted-public-keys = [
    # "lantian:EeAUQ+W+6r7EtwnmYjeVwx5kOGEBpjlBfPlzGlTNvHc="
    "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="
  ];
  # boot.initrd.luks.cryptoModules deliberately left at the nixpkgs default.
  # The previous override listed the default set minus "cryptd" and
  # "input_leds" (the capslock LED used while typing the passphrase), i.e. it
  # silently removed two modules -- not, as the comment implied, added exotic
  # ciphers. Deleting the override restores the full default set.
  nixpkgs.overlays = [ inputs.nix-cachyos-kernel.overlays.pinned ];
  boot.kernelPackages = pkgs.cachyosKernels."linuxPackages-cachyos-latest";

  # Desktop doesn't need USB autosuspend — prevents device wakeup issues
  # transparent_hugepage=madvise: allows THP for madvise'd regions (games/Proton) without globally wasting RAM
  # preempt=full: lower latency for interactive/desktop workloads
  # nvme_core.default_ps_max_latency_us=0: prevents NVMe power state transitions (latency spikes)
  # numa_balancing=disable: single-socket AMD doesn't need NUMA balancing overhead
  # mitigations=off: disables CPU speculation mitigations for gaming perf (security tradeoff)
  # amd_prefcore=enable: scheduler prefers fastest cores on Ryzen with amd-pstate
  boot.kernelParams = [
    "usbcore.autosuspend=-1"
    "transparent_hugepage=madvise"
    "preempt=full"
    "nvme_core.default_ps_max_latency_us=0"
    "numa_balancing=disable"
    "mitigations=off"
    "amd_prefcore=enable"
  ];

  # Lower-latency PipeWire for gaming, but keep min-quantum low so the graph
  # can relax when nothing latency-sensitive is running. The old config set
  # min-quantum = quantum = 128, which pinned a ~2.7ms wakeup permanently
  # (measurable idle CPU/power cost for no benefit outside games).
  services.pipewire.extraConfig.pipewire."92-low-latency" = {
    "context.properties" = {
      "default.clock.rate" = 48000;
      "default.clock.quantum" = 128;
      "default.clock.min-quantum" = 32;
      "default.clock.max-quantum" = 2048;
    };
  };

  # System identification
  networking.hostName = "pc";

  # Power profiles — enables Noctalia's power profile UI (PowerSaver/Balanced/
  # Performance) via amd-pstate. Notebooks use TLP instead.
  services.power-profiles-daemon.enable = true;

  # AMD GPU Configuration (RX6800)
  hardware.amdgpu.opencl.enable = true;

  # Wayland
  environment.sessionVariables = {
    AMD_VULKAN_ICD = "RADV";
    LIBVA_DRIVER_NAME = "radeonsi";
  };
}
