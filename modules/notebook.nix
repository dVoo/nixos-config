{
  inputs,
  config,
  lib,
  pkgs,
  ...
}:

{
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # TLP replaces power-profiles-daemon on notebooks. It conflicts with ppd,
  # so ppd is only enabled on the desktop host (pc) now. tlp-pd exposes a
  # ppd-compatible D-Bus interface (net.hadess.PowerProfiles), so Noctalia's
  # power_profile widget works on notebooks too — manual profile switching
  # (PowerSaver/Balanced/Performance) maps to TLP's platform profiles.
  services.tlp = {
    enable = true;
    pd.enable = true;
    settings = {
      # Battery charge thresholds (ThinkPads with BAT0 charge_control sysfs).
      # The Dell XPS 13 9370 lacks these sysfs files; TLP detects this and
      # skips the writes, so it's safe to set them globally here.
      START_CHARGE_THRESH_BAT0 = 80;
      STOP_CHARGE_THRESH_BAT0 = 85;

      # Audio power saving (replaces the old snd_hda_intel modprobe option).
      SOUND_POWER_SAVE_ON_AC = 1;
      SOUND_POWER_SAVE_ON_BAT = 1;
      SOUND_POWER_SAVE_CONTROLLER = "Y";

      # PCIe active state power management. `default` on AC is TLP's own
      # default and what the `pcie_aspm.policy=powersupersave` boot param in
      # hosts/yoga/configuration.nix is overridden by at runtime — the previous
      # `performance` here did the opposite of that param (it switches ASPM
      # off entirely) and bought nothing on AC.
      PCIE_ASPM_ON_AC = "default";
      PCIE_ASPM_ON_BAT = "powersupersave";

      # Wi-Fi power saving. tlp-pd maps the Performance profile to
      # WIFI_PWR_ON_AC and Balanced/PowerSaver to WIFI_PWR_ON_BAT (see
      # share/tlp/func.d/25-tlp-func-rf) — the keys are profile-keyed, not
      # power-source-keyed, so ON_BAT="on" means PS is on in Balanced and
      # PowerSaver whether or not the charger is plugged in. PS on costs
      # latency: ~100 ms RTT plateaus to the router for seconds at a time
      # (idle measurement: 112 ms max, 18 spikes >25 ms over 4 min; PS off:
      # 10 ms max, zero spikes), which shows up in GeForce Now as lag — pick
      # Performance before streaming.
      WIFI_PWR_ON_AC = "off";
      WIFI_PWR_ON_BAT = "on";

      # Disable Wake-on-LAN (replaces the old eth* udev rule).
      WOL_DISABLE = "Y";

      # Bluetooth off while on battery (user choice). The radio idles around
      # 0.1-0.3 W; the adapter is already autosuspended, so this is a small
      # win. Re-enable from Noctalia's panel (or `rfkill unblock bluetooth`)
      # when you need a BT keyboard/mouse/headset.
      DEVICES_TO_DISABLE_ON_BAT = "bluetooth";

      # NVMe power management. DISK_APM_LEVEL_* and DISK_DEVICES are gone:
      # APM is a SATA concept (the old comment here already admitted NVMe
      # ignores it), so the 254/254 pair documented "maximum performance, no
      # saving" while having no effect at all.

      # CPU scaling governor is managed by the kernel/intel_pstate driver.
      CPU_ENERGY_PERF_POLICY_ON_AC = "balance_performance";
      CPU_ENERGY_PERF_POLICY_ON_BAT = "balance_power";

      # Platform profile (replaces ppd's PowerSaver/Balanced/Performance).
      # Battery always wins by design: on battery the platform is pinned to
      # `low-power` in both the Balanced (PP_BAL) and PowerSaver (PP_SAV, which
      # falls back to _ON_BAT) profiles, so the two battery profiles are
      # deliberately identical. The trade-off is that nothing in the Noctalia
      # profile switcher can raise the platform limit while unplugged. On AC
      # `balanced` is used rather than TLP's `performance` default, so
      # selecting Performance is inert at the platform level too
      # (CPU_ENERGY_PERF_POLICY_ON_AC stays balance_performance regardless).
      PLATFORM_PROFILE_ON_AC = "balanced";
      PLATFORM_PROFILE_ON_BAT = "low-power";

      # Power-source profile switching is left at TLP's defaults
      # (TLP_AUTO_SWITCH=2 "smart", TLP_PROFILE_AC=PRF, TLP_PROFILE_BAT=BAL) —
      # smart mode keeps whatever profile you picked until you are back on that
      # source's default, which is the wanted behaviour here.

      # Opportunistic turbo on battery: intel_pstate reported
      # hwp_dynamic_boost=0 on battery already (TLP default), but set it
      # explicitly so the effective config is auditable in the repo rather
      # than depending on TLP's defaults not drifting.
      CPU_HWP_DYN_BOOST_ON_BAT = 0;

      # Runtime PM: auto-suspend idle PCI(e) devices. Also TLP defaults,
      # made explicit for the same reason — tlp-stat and
      # scripts/battery-measure.sh must be able to show intent vs. reality.
      RUNTIME_PM_ON_BAT = "auto";
      USB_AUTOSUSPEND = 1;

      # Laptop-mode-style writeback. TLP writes this to dirty_expire_centisecs
      # (and dirty_writeback_centisecs), i.e. it is the maximum age a dirty
      # page may reach before writeback — not a tuning knob that saves
      # measurable power on NVMe. It was left at 60 (TLP's own default, and
      # redundant with it in a file that otherwise only pins non-defaults),
      # which means up to a minute of writes can be lost on a crash or power
      # loss. 30 is TLP's AC value and the safer window.
      MAX_LOST_WORK_SECS_ON_BAT = 30;
      # NMI_WATCHDOG dropped: boot.kernel.sysctl already sets
      # kernel.nmi_watchdog=0 on every host.
    };
  };

  services.upower.enable = true;

  # The compositor owns lid-close handling on laptops: niri's switch-events
  # lock via Noctalia and then suspend (see modules/niri.nix; Hyprland's
  # lid binding mirrors it). logind must not act on the lid switch too, or
  # both paths race to suspend — and on the X1 Yoga logind loses its evdev
  # watch on the lid device after the first s2idle cycle anyway, so it is
  # the wrong owner regardless.
  services.logind.settings.Login = {
    HandleLidSwitch = "ignore";
    HandleLidSwitchExternalPower = "ignore";
    HandleLidSwitchDocked = "ignore";
  };

  environment.systemPackages = [
    pkgs.powertop
  ]
  # Package watts + Pkg%pc10 residency — used by scripts/battery-measure.sh.
  # powertop alone cannot tell whether the package reaches its deepest
  # idle state, which is the single most useful number for attributing
  # idle power. Take turbostat from boot.kernelPackages so its version
  # always matches the running kernel (it reads version-specific MSRs).
  ++ [ config.boot.kernelPackages.turbostat ]
  # Device names for battery-measure.sh's runtime-PM audit — raw BDFs like
  # 0000:00:16.3 are not attributable without lspci/lsusb.
  ++ [
    pkgs.pciutils
    pkgs.usbutils
  ];

  services.udev.packages = [ pkgs.brightnessctl ];

  services.udev.extraRules = ''
    ACTION=="add|change", SUBSYSTEM=="backlight", KERNEL=="intel_backlight", MODE="0664", GROUP="video"

    # Matches standard ThinkPad sensors (Synaptics 06cb, Goodix, etc.) via product strings & vendor ID
    ACTION=="add|change", SUBSYSTEM=="usb", ATTRS{product}=="*Fingerprint*", ATTR{power/wakeup}="disabled", ATTR{power/control}="auto"
    ACTION=="add|change", SUBSYSTEM=="usb", ATTRS{product}=="*FingerPrint*", ATTR{power/wakeup}="disabled", ATTR{power/control}="auto"
    ACTION=="add|change", SUBSYSTEM=="usb", ATTRS{idVendor}=="06cb", ATTR{power/wakeup}="disabled", ATTR{power/control}="auto"
  '';

  # ProtonVPN (NetworkManager WireGuard connection, iface "proton0", MTU 1420)
  # suffers from PMTUD blackholing: ICMP "fragmentation needed" is dropped
  # somewhere along the path, so the kernel never learns the real path MTU
  # (~1328, verified via `ping -M do -s 1300`). Small packets (ping, tiny
  # HTTP responses) pass; large ones (TLS handshakes, HTTPS page loads)
  # silently vanish.
  #
  # --clamp-mss-to-pmtu is useless here because it uses the interface MTU
  # (1420 → MSS 1380), which is still above the real path MTU. We use an
  # explicit --set-mss 1280 (path MTU 1320, safely below the verified 1328)
  # so TCP segments fit through the tunnel regardless of PMTUD.
  #
  # Both directions must be clamped: outbound SYN (client's MSS) via
  # POSTROUTING, and inbound SYN-ACK (server's MSS) via PREROUTING. FORWARD
  # rules are omitted — the notebook is the endpoint, not a router.
  #
  # Idempotency: these live in the mangle table, which iptables-restore in
  # firewall-start does not reset, and the unit is restarted on every
  # `nixos-rebuild switch`. A bare -A therefore appended a fresh copy of each
  # rule on every switch (and still would after every reboot-free restart).
  # Each rule is now deleted first (silently, ignoring "no such rule") and
  # then appended, so exactly one copy of each exists. A reboot clears the
  # duplicates that accumulated before this change.
  #
  # IPv6 is the actual trap: ProtonVPN routes IPv6 default traffic through
  # "ipv6leakintrf0" (a leak-protection dummy iface, MTU 1500) and the real
  # path MTU there is also ~1328. curl/browsers try IPv6 first, so the TLS
  # ClientHello (1555 bytes) is silently dropped while IPv4 HTTPS works.
  # The same TCPMSS rules must be applied via ip6tables for both interfaces.
  networking.firewall.extraCommands = ''
    iptables -t mangle -D POSTROUTING -o proton0 -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --set-mss 1280 2>/dev/null || true
    iptables -t mangle -A POSTROUTING -o proton0 -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --set-mss 1280
    iptables -t mangle -D PREROUTING -i proton0 -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --set-mss 1280 2>/dev/null || true
    iptables -t mangle -A PREROUTING -i proton0 -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --set-mss 1280
    ip6tables -t mangle -D POSTROUTING -o proton0 -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --set-mss 1280 2>/dev/null || true
    ip6tables -t mangle -A POSTROUTING -o proton0 -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --set-mss 1280
    ip6tables -t mangle -D PREROUTING -i proton0 -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --set-mss 1280 2>/dev/null || true
    ip6tables -t mangle -A PREROUTING -i proton0 -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --set-mss 1280
    ip6tables -t mangle -D POSTROUTING -o ipv6leakintrf0 -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --set-mss 1280 2>/dev/null || true
    ip6tables -t mangle -A POSTROUTING -o ipv6leakintrf0 -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --set-mss 1280
    ip6tables -t mangle -D PREROUTING -i ipv6leakintrf0 -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --set-mss 1280 2>/dev/null || true
    ip6tables -t mangle -A PREROUTING -i ipv6leakintrf0 -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --set-mss 1280
  '';
}
