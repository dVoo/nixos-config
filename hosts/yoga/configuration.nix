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

  # Periodic SSD trim is enabled for all hosts in modules/common.nix (it is
  # now the only discard mechanism, since the mount-level discard options
  # were removed).

  environment.sessionVariables = {
    LIBVA_DRIVER_NAME = "iHD";
    NIXOS_OZONE_WL = "1";
  };

  hardware.graphics.extraPackages = [ pkgs.intel-media-driver ];

  # i915 display power saving — biggest idle-power lever on Intel iGPUs.
  # enable_dc=2     up to DC6. NOT 4: the only thing 4 adds is DC3CO, and the
  #                  DMC's "DC3CO count" stayed 0 across two measured runs with
  #                  enable_dc=4 — upstream refuses DC3CO while PSR selective
  #                  fetch is enabled ("drm/i915/display: Do not allow DC3CO if
  #                  PSR SF is enabled") and this panel runs PSR2 + selective
  #                  fetch. So 4 is inert here and was reverted. Revisit only
  #                  if PSR SF is ever turned off (enable_psr=1).
  # enable_fbc=1    framebuffer compression. NOTE: i915_fbc_status shows
  #                  "FBC disabled: Selective update enabled" — FBC and
  #                  PSR2 selective fetch are mutually exclusive on this
  #                  platform and PSR2 SU is the better one, so FBC staying
  #                  off is correct. Do not chase this.
  # enable_psr=2    panel self-refresh on eDP (~1W on modern ThinkPad panels)
  #                  Measured active: PSR2 + selective fetch, SU_STANDBY.
  # Verify after boot: cat /sys/module/i915/parameters/enable_psr
  boot.extraModprobeConfig = ''
    options i915 enable_dc=2 enable_fbc=1 enable_psr=2
    options snd_hda_intel power_save_controller=Y
  '';
  # snd_sof_pci does NOT have a `power_save` parameter (verified with
  # `modinfo -F parm snd-sof-pci` on the running kernel: only fw_*/lib_*/
  # tplg_*/ipc_type/sof_pci_debug exist), so the `options snd_sof_pci
  # power_save=1` line that used to live above was a silent no-op. Audio
  # runtime power saving comes from TLP (SOUND_POWER_SAVE_*,
  # modules/notebook.nix), which drives snd_hda_intel's power_save.

  # Boot-time PCIe ASPM policy: force-enable link power management (L0s/L1)
  # on every ASPM-capable device, not only the ones the BIOS enables. This
  # reduces power on idle PCIe links; it is NOT what gates package C10 here.
  #
  # Honesty note: this was added on the theory that PC10 was unreachable
  # because links never entered L1 — turbostat reported Pk%pc10=0.00%
  # throughout a 5-minute sample. That theory is NOT supported. The pmc_core
  # cumulative counters over an ordinary 16-minute window show PC10 as the
  # *single largest* package state (54.6% of accounted package time; ~37% of
  # wall clock), ahead of PC8 (25.9%) and PC2 (14.7%). The 0.00% sample is
  # best explained by that window being busy (load avg 1.45, ~1100 IRQ/s, a
  # nix evaluation running on this same host), not by a PCIe blocker.
  #
  # Kept as a low-risk link-power measure, not as a proven fix. Verify with:
  # sudo lspci -vv | grep -A2 LnkCtl   (want L0s/L1 "Enabled")
  # Revert if Wi-Fi/BT shows flakiness (then deny specific devices instead).
  boot.kernelParams = [ "pcie_aspm.policy=powersupersave" ];

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
    #
    # StartLimitIntervalSec must go in [Unit], not [Service]: since systemd
    # v230 it is a unit-level setting, and in serviceConfig the section is
    # [Service], where systemd ignores it (`systemd-analyze verify` reports
    # "Unknown key 'StartLimitIntervalSec' in section [Service], ignoring").
    # Left in serviceConfig it silently kept the default 5-starts/10s limiter,
    # so the restart loop still gave up permanently — the exact failure the
    # Restart=always below is meant to prevent.
    unitConfig.StartLimitIntervalSec = 0;
    serviceConfig = {
      ExecStartPre = "${pkgs.bash}/bin/bash -c 'for i in $(seq 1 30); do busctl --system status net.hadess.SensorProxy >/dev/null 2>&1 && exit 0; sleep 1; done; exit 1'";
      Restart = lib.mkForce "always";
      RestartSec = "2s";
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
