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
  nixpkgs.overlays = [ inputs.nix-cachyos-kernel.overlays.pinned ];
  # boot.kernelPackages = lib.mkForce pkgs.cachyosKernels."linuxPackages-cachyos-latest-x86_64-v3";
  boot.kernelPackages = lib.mkForce pkgs.cachyosKernels."linuxPackages-cachyos-latest";

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

  # Aggressive PipeWire low-latency config for gaming
  services.pipewire.extraConfig.pipewire."92-low-latency" = {
    "context.properties" = {
      "default.clock.rate" = 48000;
      "default.clock.quantum" = 128;
      "default.clock.min-quantum" = 128;
      "default.clock.max-quantum" = 2048;
    };
  };

  # System identification
  networking.hostName = "pc";

  # AMD GPU Configuration (RX6800)
  hardware.amdgpu.opencl.enable = true;

  # Wayland
  environment.sessionVariables = {
    AMD_VULKAN_ICD = "RADV";
  };
}
