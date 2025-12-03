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
          root = {
            size = "100%";
            type = "8309";
            content = {
              type = "luks";
              name = "crypt";
              # LUKS encryption - set your passphrase during install
              settings.keyFile = "/tmp/secret.key";
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
  };
}

