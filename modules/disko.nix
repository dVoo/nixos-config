{
  disko.devices = {
    disk.main = {
      type = "disk";
      device = "/dev/nvme0n1";
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
              mountOptions = [
                "defaults"
              ];
            };
          };
          swap = {
            size = "32G";
            type = "8200";
            content = {
              type = "swap";
              randomEncryption = true;
              # discardPolicy removed along with the other continuous-discard
              # options; swap is re-encrypted with a fresh random key on every
              # boot, so there is nothing to gain from discarding on swapoff.
            };
          };
          root = {
            size = "100%";
            type = "8309";
            content = {
              type = "luks";
              name = "crypt";
              # Kept: dm-crypt refuses TRIM unless this is enabled, so without
              # it the periodic fstrim timer (services.fstrim in
              # modules/common.nix) would be a silent no-op on the encrypted
              # volumes. The privacy trade-off (an observer can see which
              # blocks are unused) is accepted; the continuous `discard=async`
              # mount options are gone, so TRIM now runs in batches on the
              # timer instead of on every write.
              settings.allowDiscards = true;
              content = {
                type = "btrfs";
                extraArgs = [
                  "-f"
                  "-L"
                  "nixos"
                ];
                subvolumes = {
                  # zstd:1 rather than zstd:3 (and no `discard=async`, no `ssd`).
                  # Level 3 costs noticeably more CPU on every write for a
                  # marginal space gain, and `ssd` is auto-detected by modern
                  # btrfs (a no-op). Continuous discards were replaced by the
                  # fstrim timer. NOTE: mount options only apply to newly
                  # written data unless a `btrfs balance` / `defrag` is run
                  # once per subvolume.
                  "@" = {
                    mountpoint = "/";
                    mountOptions = [
                      "subvol=@"
                      "compress=zstd:1"
                      "noatime"
                    ];
                  };
                  "@home" = {
                    mountpoint = "/home";
                    mountOptions = [
                      "subvol=@home"
                      "compress=zstd:1"
                      "noatime"
                    ];
                  };
                  # The store and the logs are the two write-heavy subvolumes;
                  # they gain the least from compression (packages are often
                  # already compressed) and pay the most CPU for it.
                  "@nix" = {
                    mountpoint = "/nix";
                    mountOptions = [
                      "subvol=@nix"
                      "compress=zstd:1"
                      "noatime"
                    ];
                  };
                  "@var" = {
                    mountpoint = "/var";
                    mountOptions = [
                      "subvol=@var"
                      "compress=zstd:1"
                      "noatime"
                    ];
                  };
                  "@log" = {
                    mountpoint = "/var/log";
                    mountOptions = [
                      "subvol=@log"
                      "compress=zstd:1"
                      "noatime"
                    ];
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
