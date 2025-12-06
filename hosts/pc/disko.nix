{
  disko.devices = {
    disk.main = {
      type = "disk";
      device = "/dev/nvme0n1";  # CHANGE THIS TO YOUR DISK (/dev/sda, etc.)
      content = {
        type = "gpt";
        partitions = {
          ESP = {
            size = "512M";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
            };
          };
          swap = {
            size = "32G";  # Adjust based on RAM (RAM size recommended)
            type = "8200";
            content = {
              type = "swap";
              randomEncryption = true;  # Auto-encrypts with random key
            };
          };
          root = {
            size = "100%";
            type = "8309";
            content = {
              type = "luks";
              name = "crypt";
              content = {
                type = "btrfs";
                extraArgs = [ "-f" "-L" "nixos" ];
                subvolumes = {
                  "@" = {
                    mountpoint = "/";
                    mountOptions = [ "subvol=@" "compress=zstd:1" "noatime" "ssd" ];
                  };
                  "@home" = {
                    mountpoint = "/home";
                    mountOptions = [ "subvol=@home" "compress=zstd:1" ];
                  };
                  "@nix" = {
                    mountpoint = "/nix";
                    mountOptions = [ "subvol=@nix" "compress=zstd:1" "noatime" ];
                  };
                  "@var" = {
                    mountpoint = "/var";
                    mountOptions = [ "subvol=@var" "compress=zstd:1" ];
                  };
                  "@log" = {
                    mountpoint = "/var/log";
                    mountOptions = [ "subvol=@log" "compress=zstd:1" ];
                  };
                };
              };
            };
          };
        };
      };
    };
    nodev = {
      "/mnt/gamedata" = {
        fsType = "ext4";
        device = "/dev/disk/by-uuid/55946413-9c80-4ed5-8bbd-6c3b09488d7d";
        mountOptions = [ "defaults" "noatime" "commit=30" "dioread_nolock" "nodiratime" ];
      };
    };
  };
}

