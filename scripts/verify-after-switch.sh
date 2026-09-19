#!/usr/bin/env bash
# Post-switch verification for the config cleanup.
#
#   bash ~/nixos-config/scripts/verify-after-switch.sh
#
# Read-only: it inspects state and prints what it finds. Run it after
# `sudo nixos-rebuild switch`. Lines prefixed "CHECK" are the ones that
# indicated a real bug during the audit; "---" lines are raw data to eyeball.
set -u

ok() { printf '  ok    %s\n' "$*"; }
bad() { printf '  CHECK %s\n' "$*"; }
note() { printf '  ---   %s\n' "$*"; }

echo "== session / compositor"
if systemctl --user is-active niri.service >/dev/null 2>&1; then
  ok "niri.service active"
else
  note "niri.service not active (running a different session?)"
fi

if journalctl --user-unit=niri -b --no-pager 2>/dev/null | grep -q 'listening on X11 socket'; then
  ok "niri X11 socket up (xwayland-satellite integration)"
else
  bad "no 'listening on X11 socket' in niri's journal -- X11 apps (Steam) will not start"
fi

if journalctl --user-unit=niri -b --no-pager 2>/dev/null | grep -qi 'waybar'; then
  bad "niri still logs a waybar spawn failure (it is not installed; Noctalia is the bar)"
else
  ok "no waybar spawn errors"
fi

if pgrep -x hyprpolkitagent >/dev/null 2>&1; then
  ok "polkit agent (hyprpolkitagent) running"
else
  bad "no polkit agent -- GUI privilege prompts will fail (test with: pkexec true)"
fi

echo "== fish startup (the generated config must source cleanly)"
if command -v fish >/dev/null 2>&1; then
  ferr=$(fish -c 'source $HOME/.config/fish/config.fish' 2>&1)
  if [ -n "$ferr" ]; then
    bad "fish errors while sourcing the generated config.fish:"
    printf '  ---   %s\n' "$ferr" | head -5
  else
    ok "fish sources the generated config.fish without errors"
  fi
else
  note "fish not on PATH"
fi

echo "== lid switch"
if grep -qs '^HandleLidSwitch=ignore' /etc/systemd/logind.conf; then
  ok "logind ignores the lid switch (niri owns lock+suspend)"
else
  bad "logind still handles the lid -- expect a double-suspend race"
fi
note "logind 'Lid closed' events this boot (want 0, niri handles it): $(journalctl -b --no-pager 2>/dev/null | grep -c 'Lid closed')"
note "close and reopen the lid once, then check: journalctl -b | grep -iE 'lid|suspend'"

echo "== swap / zram (swappiness 150 and page-cluster 0 are the tuned values)"
note "swappiness=$(cat /proc/sys/vm/swappiness) page-cluster=$(cat /proc/sys/vm/page-cluster) nmi_watchdog=$(cat /proc/sys/kernel/nmi_watchdog)"
zramctl --output NAME,ALGORITHM,DISKSIZE,DATA,COMPR 2>/dev/null | head -3 | sed 's/^/  ---   /'
swapon --show | sed 's/^/  ---   /'
note "zram (prio 100) must be used before the disk swap (-2); load a big program to confirm DATA grows"

echo "== TRIM / btrfs"
if systemctl is-enabled fstrim.timer >/dev/null 2>&1; then
  ok "fstrim.timer enabled (now the only discard mechanism)"
else
  bad "fstrim.timer not enabled -- nothing discards free blocks any more"
fi
for m in / /home /nix /boot; do
  note "$m: $(findmnt -no OPTIONS "$m" 2>/dev/null)"
done
note "want: compress=zstd:1, noatime, and NO discard=async. Mount options only affect"
note "newly written data -- one 'sudo btrfs filesystem defragment -r -czstd:1 <subvol>' per"
note "subvolume (or a balance) recompresses existing data."

echo "== VPN MSS clamping"
if command -v iptables >/dev/null 2>&1; then
  note "v4 mangle rules containing 1280: $(sudo iptables-save -t mangle 2>/dev/null | grep -c 1280) (want 1 per interface)"
  note "v6 mangle rules containing 1280: $(sudo ip6tables-save -t mangle 2>/dev/null | grep -c 1280)"
  note "reboot once after this change: it clears the duplicates older switches accumulated"
fi
if ip -brief addr show proton0 >/dev/null 2>&1; then
  note "proton0 is up -- verify a large TLS transfer, e.g. curl -sSI https://ifconfig.me"
else
  note "proton0 not up (VPN off) -- bring it up and re-check the counters above"
fi

echo "== gaming (pc only)"
if [ -e /dev/ntsync ]; then
  note "$(ls -l /dev/ntsync | tr -s ' ') (want crw-rw-rw-)"
else
  note "no /dev/ntsync (not the pc, or the module is not loaded)"
fi
if command -v clinfo >/dev/null 2>&1; then
  note "OpenCL platforms (want exactly one: ROCm):"
  clinfo -l 2>/dev/null | sed 's/^/  ---   /'
fi

echo "== Noctalia"
if [ -f "$HOME/.config/noctalia/config.toml" ]; then
  ok "~/.config/noctalia/config.toml present"
else
  bad "no ~/.config/noctalia/config.toml"
fi
# on the machines that have one)
backlight=""
for bl in /sys/class/backlight/*/brightness; do
  [ -e "$bl" ] && backlight="$bl" && break
done
if [ -n "$backlight" ] && command -v brightnessctl >/dev/null 2>&1; then
  note "backlight: $(brightnessctl -m 2>/dev/null | head -1)"
else
  note "no backlight on this host: the dim/resume hook is host-gated off (expected on pc)"
fi
note "idle dim test: wait 150s and confirm the panel dims and restores"

echo "== secrets / API keys"
note "decrypted secrets:"
ls -l /run/agenix/ 2>/dev/null | sed 's/^/  ---   /'
if [ -L "$HOME/.kube/config" ] || [ -f "$HOME/.kube/config" ]; then
  note "$(ls -l "$HOME/.kube/config" | tr -s ' ')"
  note "kubectl context: $(kubectl config current-context 2>/dev/null || echo 'unavailable')"
else
  bad "no ~/.kube/config"
fi
for v in OLLAMA_API_KEY OPENROUTER_API_KEY DEEPSEEK_API_KEY OPENCODE_API_KEY; do
  if [ -n "${!v:-}" ]; then
    ok "$v present in this shell"
  else
    note "$v not set here (expected: only login shells source hm-session-vars.sh)"
  fi
done
note "launcher test: start opencode/aichat from the Noctalia launcher and confirm they authenticate"

echo "== user-profile GC timer"
systemctl --user list-timers 'nix-gc-user*' --no-pager 2>/dev/null | sed 's/^/  ---   /'

echo "== storage / generations"
df -h /boot / 2>/dev/null | sed 's/^/  ---   /'
note "system generations: $(ls -1 /nix/var/nix/profiles/ 2>/dev/null | grep -c system)  boot entries: $(ls -1 /boot/loader/entries 2>/dev/null | wc -l) (configurationLimit=10)"
note "installed closure: $(nix path-info -rSh /run/current-system 2>/dev/null | tail -1 | tr -s ' ') (pre-cleanup baseline: 19.1 GiB / 2196 paths)"

echo "== warnings since boot"
note "warning lines: $(journalctl -b -p warning --no-pager 2>/dev/null | wc -l)"
note "review: journalctl -b -p warning --no-pager | tail -40"
note "boot time: $(systemd-analyze 2>/dev/null | head -1)"
note "battery: compare 10 min idle discharge (powertop --time=600) with the pre-cleanup number"
