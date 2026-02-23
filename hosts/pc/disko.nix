{
  imports = [ ../../modules/disko.nix ];

  disko.devices.nodev = {
    "/mnt/gamedata" = {
      fsType = "ext4";
      device = "/dev/disk/by-uuid/55946413-9c80-4ed5-8bbd-6c3b09488d7d";
      mountOptions = [
        "defaults"
        "noatime"
        "commit=30"
        "dioread_nolock"
        "nodiratime"
      ];
    };
  };
}
