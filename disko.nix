{
  # Two independent disks, no RAID. Recovery story for a failed system disk
  # is re-running nixos-anywhere, not degraded-array operation.
  disko.devices.disk = {
    system = {
      type = "disk";
      device = "/dev/disk/by-id/nvme-Micron_7450_MTFDKCC1T9TFR_23013ECB134B";
      content = {
        type = "gpt";
        partitions = {
          ESP = {
            size = "1G";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = [ "umask=0077" ];
            };
          };
          root = {
            size = "100%";
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/";
            };
          };
        };
      };
    };
    data = {
      type = "disk";
      device = "/dev/disk/by-id/nvme-Micron_7450_MTFDKCC1T9TFR_23013ECB12EC";
      content = {
        type = "gpt";
        partitions.data = {
          size = "100%";
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/data";
          };
        };
      };
    };
  };
}
