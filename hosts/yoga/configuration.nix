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
    ../../modules/disko.nix
    ../../modules/common.nix
    ../../modules/notebook.nix
    nixos-hardware.nixosModules.lenovo-thinkpad-x1-yoga-7th-gen
  ];

  # System identification
  networking.hostName = "yoga";

  # Alder Lake-U benefits from thermald for thermal/throttling management
  services.thermald.enable = true;

  # Periodic SSD trim on top of the mount-level discard options
  services.fstrim.enable = true;

  environment.sessionVariables = {
    LIBVA_DRIVER_NAME = "iHD";
    NIXOS_OZONE_WL = "1";
  };

  hardware.graphics.extraPackages = [ pkgs.intel-media-driver ];

  # i915 display power saving — biggest idle-power lever on Intel iGPUs.
  # enable_dc=2     deepest display C-states
  # enable_fbc=1    framebuffer compression → less memory traffic
  # enable_psr=2    panel self-refresh on eDP (~1W on modern ThinkPad panels)
  # Verify after boot: cat /sys/module/i915/parameters/enable_psr
  boot.extraModprobeConfig = ''
    options i915 enable_dc=2 enable_fbc=1 enable_psr=2
    options snd_hda_intel power_save_controller=Y
    options snd_sof_pci power_save=1
  '';

  # Auto-rotate — iio-sensor-proxy exposes the accelerometer over D-Bus;
  # iio-niri listens for orientation changes and applies the matching Niri
  # output transform. The upstream module binds the user service to
  # niri.service with Restart=on-failure, but iio-niri exits with status 0
  # after a transient D-Bus timeout (race against iio-sensor-proxy at boot),
  # so on-failure never fires and rotation stays dead until reboot. We
  # override with Restart=always + a backoff so it self-heals, and gate the
  # start on iio-sensor-proxy's system D-Bus name being claimed.
  hardware.sensor.iio.enable = true;

  services.iio-niri = {
    enable = true;
    extraArgs = [
      "--monitor"
      "eDP-1"
    ];
  };

  systemd.user.services.iio-niri = {
    # Wait for iio-sensor-proxy's system D-Bus name before starting. User
    # services can't directly require system services (separate namespaces),
    # so we gate via an ExecStartPre that polls the well-known name.
    serviceConfig = {
      ExecStartPre = "${pkgs.bash}/bin/bash -c 'for i in $(seq 1 30); do busctl --system status net.hadess.SensorProxy >/dev/null 2>&1 && exit 0; sleep 1; done; exit 1'";
      Restart = lib.mkForce "always";
      RestartSec = "2s";
      StartLimitIntervalSec = 0;
    };
  };
  # Fingerprint reader: kill fprintd before sleep to prevent post-resume wedging.
  #
  # The Synaptics Prometheus sensor (06cb:00fc) re-enumerates fine after
  # s2idle resume, but fprintd — D-Bus-activated and lingering up to 30 s
  # after last use — tries to suspend its device *during* the system
  # suspend transition, fails ("device still busy"), then on resume
  # re-probes the freshly-reset device from a corrupted process state:
  #   "Ignoring device due to initialization error: unsupported firmware version"
  # and thereafter every auth wedges on "Device was already claimed" —
  # a known libfprint bug (gitlab libfprint#538, ArchWiki Fprint).
  #
  # Killing fprintd before sleep removes the root cause: no stale process
  # survives suspend, so there is no stale claim on resume. The next auth
  # D-Bus-activates a fresh fprintd that probes the settled device.
  #
  # We deliberately do NOT disable sensor autosuspend (power/control=on) to
  # work around this: that would hold the USB device in D0, keep the xHCI
  # controller polling, and keep the CPU's PMU path active — an idle-power
  # regression. The udev rule in modules/notebook.nix already sets
  # power/control=auto + power/wakeup=disabled, which is the correct
  # battery-friendly state; this service leaves it untouched.
  systemd.services.fprintd-kill-before-sleep = {
    description = "Kill fprintd before sleep to prevent post-resume wedging";
    before = [ "sleep.target" ];
    unitConfig = {
      StopWhenUnneeded = true;
    };
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.procps}/bin/pkill -x fprintd";
      # pkill exits 1 when no fprintd process is running (it already idled
      # out); that is the happy path, not a failure.
      SuccessExitStatus = "0 1";
    };
    wantedBy = [ "sleep.target" ];
  };
}
