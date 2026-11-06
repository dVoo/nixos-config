# Machine-specific boot plumbing for the Dell XPS 13 9370.
#
# This is NOT `nixos-generate-config` output, so it does not carry the usual
# "do not modify" header: the disk layout, filesystems and swap come from
# modules/disko.nix, and firmware/microcode, the Intel GPU and TLP come from
# nixos-hardware's dell-xps-13-9370 module imported in
# hosts/xps/configuration.nix. What is left here is only what the initrd
# needs to find that layout, plus kvm-intel. If the real machine ever needs
# more, add it here explicitly.
{ config, lib, pkgs, modulesPath, ... }:

{
  imports =
    [ (modulesPath + "/installer/scan/not-detected.nix")
    ];

  boot.initrd.availableKernelModules = [ "nvme" "xhci_pci" "ahci" "usbhid" "usb_storage" "sd_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
