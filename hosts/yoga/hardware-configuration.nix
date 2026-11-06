# Machine-specific boot plumbing for the ThinkPad X1 Yoga Gen 7.
#
# This is NOT `nixos-generate-config` output, so it does not carry the usual
# "do not modify" header: the disk layout, filesystems and swap come from
# modules/disko.nix (disko owns /boot, /, /home, /nix, /var and the encrypted
# swap partition), and firmware/microcode, i915, TLP and fprintd come from
# nixos-hardware's lenovo-thinkpad-x1-yoga-7th-gen module imported in
# hosts/yoga/configuration.nix. What is left here is only what the initrd
# needs to find that layout, plus kvm-intel. If the real machine ever needs
# more (a different root controller, VMD, ...), add it here explicitly.
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