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
  # Fingerprint reader suspend/resume handling.
  #
  # Two distinct failure modes have been observed on the Synaptics
  # Prometheus sensor (06cb:00fc) after s2idle cycles:
  #
  # 1. Daemon-side staleness: fprintd (D-Bus-activated, lingering up to
  #    30 s after last use) survives into the suspend transition with its
  #    USB device still claimed, then re-probes the resumed device from a
  #    corrupted state (libfprint#538). Fixed by stopping fprintd cleanly
  #    BEFORE sleep: `systemctl stop` waits for the process to actually
  #    exit and release the device (a bare pkill returned before the
  #    process finished dying, which is why "User destroyed open device!"
  #    and libusb "still referenced" warnings kept appearing).
  #
  # 2. Device-side firmware crash: after several suspend cycles the sensor
  #    firmware itself wedges mid-operation:
  #      "Ignoring device due to initialization error: unsupported firmware
  #       version"
  #    (seen Jul 17 / Jul 23 / Aug 14 2026). fprintd permanently ignores a
  #    device that failed init, and the device stays wedged until it is
  #    re-enumerated. The resume unit below probes fprintd's device list
  #    after every resume and only when the sensor is wedged (0 devices /
  #    probe failure) toggles the USB port's `authorized` flag (0 -> 1 =
  #    forced re-enumeration = firmware reset) and restarts fprintd so it
  #    re-probes the reset device. Enrolled templates live in the sensor's
  #    persistent flash and survive this. Resetting unconditionally is NOT
  #    safe: it races with the lock screen's fprintd activation and leaves
  #    the lock screen without fingerprint auth (observed Sep 05 2026).
  #
  # NOTE on enrollment: templates are stored in sensor flash while the
  # user->print mapping lives in /var/lib/fprint. `sudo fprintd-enroll`
  # WITHOUT a username enrolls for root, leaving the user with
  # NoEnrolledPrints — always pass the username explicitly.
  #
  # We deliberately do NOT disable sensor autosuspend (power/control=on) to
  # work around any of this: that would hold the USB device in D0, keep the
  # xHCI controller polling, and keep the CPU's PMU path active — an
  # idle-power regression. The udev rule in modules/notebook.nix already
  # sets power/control=auto + power/wakeup=disabled, which is the correct
  # battery-friendly state, and re-applies them on the re-enumeration
  # triggered by the resume unit below.
  systemd.services.fprintd-stop-before-sleep = {
    description = "Stop fprintd before sleep to prevent post-resume wedging";
    before = [ "sleep.target" ];
    unitConfig = {
      StopWhenUnneeded = true;
    };
    serviceConfig = {
      Type = "oneshot";
      # Stop is idempotent (exit 0 when fprintd already idled out) and
      # waits for the device to be released. Bound the wait so a hung
      # fprintd cannot delay suspend indefinitely; a timeout here does
      # not block sleep.target (WantedBy, not RequiredBy) and systemd
      # SIGKILLs the stuck process on stop timeout anyway.
      ExecStart = "${pkgs.systemd}/bin/systemctl stop fprintd.service";
      TimeoutStartSec = "10s";
    };
    wantedBy = [ "sleep.target" ];
  };

  systemd.services.fprintd-usb-reset-on-resume = {
    description = "Heal wedged fingerprint sensor after resume";
    after = [ "systemd-suspend.service" ];
    unitConfig = {
      StopWhenUnneeded = true;
    };
    serviceConfig = {
      Type = "oneshot";
      # An unconditional USB reset on every resume turned out to be worse
      # than the disease: the deauthorize window races with the lock
      # screen's fprintd D-Bus activation, the probe hits a missing device
      # ("Entity not found [-5]") and noctalia's fingerprint client gives
      # up for the rest of the lock session. So: probe fprintd's view of
      # the world first, and only reset the USB device when the sensor is
      # actually wedged (fprintd reports 0 devices / fails to start).
      ExecStart = pkgs.writeShellScript "fprintd-usb-reset-on-resume" ''
        set -u
        # Ask fprintd's Manager interface how many devices it sees. This
        # D-Bus-activates fprintd (or joins the activation already racing
        # from the lock screen) and needs no username/polkit, unlike
        # fprintd-list which requires a <username> argument.
        probe() {
          ${pkgs.coreutils}/bin/timeout 15 ${pkgs.systemd}/bin/busctl call net.reactivated.Fprint /net/reactivated/Fprint/Manager net.reactivated.Fprint.Manager GetDevices 2>&1 || true
        }
        healthy() {
          printf '%s' "$1" | ${pkgs.gnugrep}/bin/grep -q 'net/reactivated/Fprint/Device'
        }
        check="$(probe)"
        if healthy "$check"; then
          exit 0
        fi
        # USB may still be settling right after resume — retry once before
        # declaring the sensor wedged.
        ${pkgs.coreutils}/bin/sleep 2
        check="$(probe)"
        if healthy "$check"; then
          exit 0
        fi
        echo "fingerprint sensor wedged (fprintd probe: $check); resetting USB device"
        reset=
        for v in /sys/bus/usb/devices/*/idVendor; do
          [ -r "$v" ] || continue
          read -r vendor < "$v"
          if [ "$vendor" = "06cb" ]; then
            dev="''${v%/idVendor}"
            echo 0 > "$dev/authorized"
            ${pkgs.coreutils}/bin/sleep 1
            echo 1 > "$dev/authorized"
            reset=1
          fi
        done
        if [ -n "$reset" ]; then
          # Give the re-enumerated device time to settle, then restart
          # fprintd — it permanently ignores a device that failed init.
          # try-restart is a no-op when no fprintd is running.
          ${pkgs.coreutils}/bin/sleep 2
          ${pkgs.systemd}/bin/systemctl try-restart fprintd.service
          ${pkgs.coreutils}/bin/sleep 1
          echo "post-reset fprintd probe: $(probe)"
        else
          echo "no 06cb USB device found; nothing to reset"
        fi
      '';
    };
    wantedBy = [ "suspend.target" ];
  };
}
