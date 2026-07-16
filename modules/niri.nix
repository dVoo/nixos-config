{
  config,
  pkgs,
  osConfig,
  lib,
  ...
}:

let
  hostname = osConfig.networking.hostName;

  isLaptop = hostname == "xps" || hostname == "yoga";
  isConvertible = hostname == "yoga";
  isDesktop = hostname == "pc";

  outputConfig =
    if hostname == "yoga" then
      ''
        // X1 Yoga 7th gen — FHD+ WUXGA (1920x1200) IPS panel, 60Hz.
        // Verify with `niri msg outputs` if the mode string doesn't match.
        output "eDP-1" {
            mode "1920x1200@60.000"
            scale 1.0
        }
      ''
    else if hostname == "pc" then
      ''
        // Dual-monitor desktop — confirm exact modes with `niri msg outputs`.
        // Layout matches Hyprland: [DP-2] [DP-1] (DP-2 left of DP-1).
        // Fill in `mode` and `position` after first boot with `niri msg outputs`.
        output "DP-1" {
            // mode "<width>x<height>@<refresh>"
            scale 1.0
            // position x=<DP-2 logical width> y=0
            variable-refresh-rate on-demand=true
        }
        output "DP-2" {
            // mode "<width>x<height>@<refresh>"
            scale 1.0
            position x=0 y=0
            variable-refresh-rate on-demand=true
        }
      ''
    else
      ''
        // XPS or unknown laptop — auto-detect mode, scale 1.0.
        // Verify the output name with `niri msg outputs`.
        output "eDP-1" {
            scale 1.0
        }
      '';

  # Touch + tablet input for the X1 Yoga convertible (pen + touchscreen)
  touchTabletConfig = lib.optionalString isConvertible ''
    touch {
        map-to-output "eDP-1"
    }

    tablet {
        map-to-output "eDP-1"
    }
  '';

  # Lid switch + tablet mode events for laptops.
  # Niri reliably receives lid-switch events via libinput across
  # suspend/resume cycles. systemd-logind, by contrast, can lose its
  # evdev watch on the lid device after the first suspend/resume on some
  # Intel s2idle machines (observed on the X1 Yoga 7th gen: logind stops
  # logging "Lid closed" and never suspends again, while niri still gets
  # the event). We therefore let niri own the suspend: lock first via
  # Noctalia, then `systemctl suspend`. modules/notebook.nix sets
  # HandleLidSwitch=ignore so logind doesn't race/double-suspend.
  # On the yoga convertible, tablet mode toggles wvkbd — an on-screen
  # keyboard that works under Wayland/niri without GNOME's gsettings stack.
  switchEventsConfig =
    if isConvertible then
      ''
        switch-events {
            lid-close { spawn "sh" "-c" "noctalia msg session lock && systemctl suspend"; }
            tablet-mode-on  { spawn "${oskStart}/bin/osk-start"; }
            tablet-mode-off { spawn "${oskKill}/bin/osk-kill"; }
        }
      ''
    else if isLaptop then
      ''
        switch-events {
            lid-close { spawn "sh" "-c" "noctalia msg session lock && systemctl suspend"; }
        }
      ''
    else
      "";

  # Gaming window rules + VRR debug for desktop
  gamingConfig = lib.optionalString isDesktop ''
    // Gaming — VRR activates only when these windows are visible on the output.
    window-rule {
        match app-id=r#"^steam_app_[0-9]+$"#
        variable-refresh-rate true
        open-on-output "DP-1"
        open-fullscreen true
    }

    window-rule {
        match app-id=r#"^gamescope$"#
        variable-refresh-rate true
        open-on-output "DP-1"
        open-fullscreen true
    }
  '';

  debugConfig = lib.optionalString isDesktop ''
    debug {
        // Workaround for cursor-induced VRR spikes during games (niri v25.08+).
        // May cause the screen to appear frozen if nothing else is redrawing.
        skip-cursor-only-updates-during-vrr
    }
  '';
  # On-screen keyboard (wvkbd) wrapper scripts for the yoga convertible.
  # wvkbd is suckless-style: no config file, all styling via CLI flags.
  # Theme matches the GitHub Dark noctalia palette. Touch-friendly sizing.
  # Started hidden in tablet mode — toggle via the noctalia panel button.
  oskStart = pkgs.writeShellScriptBin "osk-start" ''
    if ! pgrep -x wvkbd-mobintl >/dev/null 2>&1; then
      ${pkgs.wvkbd}/bin/wvkbd-mobintl \
        --bg 0D1117 --fg 21262D --fg-sp 30363D \
        --press 1F6FEB --press-sp 388BFD \
        --text C9D1D9 --text-sp F0F6FC \
        --fn "DejaVu Sans 22" \
        -H 240 -L 320 \
        --hidden &
    fi
  '';
  oskKill = pkgs.writeShellScriptBin "osk-kill" ''
    pkill -x wvkbd-mobintl 2>/dev/null || true
  '';
in
{
  xdg.configFile."niri/config.kdl".text = ''
    // This config is in the KDL format: https://kdl.dev
    // "/-" comments out the following node.
    // Check the wiki for a full description of the configuration:
    // https://niri-wm.github.io/niri/Configuration:-Introduction

    ${outputConfig}

    // Input device configuration.
    input {
        keyboard {
            xkb {
                layout "eu"
            }
            numlock
        }

        touchpad {
            tap
            natural-scroll
        }

        mouse {
        }

        trackpoint {
        }
    ${touchTabletConfig}
    }

    ${switchEventsConfig}

    // Settings that influence how windows are positioned and sized.
    layout {
        gaps 8
        center-focused-column "never"
        background-color "#0D1117"

        preset-column-widths {
            proportion 0.33333
            proportion 0.5
            proportion 0.66667
        }

        default-column-width { proportion 0.5; }

        focus-ring {
            width 2
            active-color "#3B5F8A"
            inactive-color "#21262D"
            urgent-color "#F85149"
        }

        border {
            off
        }

        shadow {
            on
            softness 40
            spread 8
            offset x=0 y=8
            color "#0D111780"
        }

        tab-indicator {
            on
            hide-when-single-tab
            place-within-column
            gap 5
            width 4
            length total-proportion=1.0
            position "right"
            gaps-between-tabs 2
            corner-radius 8
            active-gradient from="#1F6FEB" to="#388BFD" angle=45
            inactive-color "#30363D"
        }

        insert-hint {
            color "#388BFD80"
        }

        struts {
        }
    }

    spawn-at-startup "waybar"

    hotkey-overlay {
        skip-at-startup
    }

    prefer-no-csd

    cursor {
        xcursor-size 32
    }

    environment {
        QT_QPA_PLATFORM "wayland"
        MOZ_ENABLE_WAYLAND "1"
        EDITOR "nvim"
    }

    screenshot-path "~/Pictures/Screenshots/Screenshot from %Y-%m-%d %H-%M-%S.png"

    animations {
        workspace-switch {
            spring damping-ratio=0.8 stiffness=600 epsilon=0.0001
        }
        horizontal-view-movement {
            spring damping-ratio=0.8 stiffness=500 epsilon=0.0001
        }
        window-movement {
            spring damping-ratio=0.8 stiffness=500 epsilon=0.0001
        }
        window-resize {
            spring damping-ratio=0.8 stiffness=500 epsilon=0.0001
        }
        overview-open-close {
            spring damping-ratio=0.7 stiffness=400 epsilon=0.0001
        }
        window-open {
            duration-ms 200
            curve "cubic-bezier" 0.05 0.7 0.1 1
        }
        window-close {
            duration-ms 150
            curve "ease-out-quad"
        }
    }

    ${debugConfig}

    // Work around WezTerm's initial configure bug
    window-rule {
        match app-id=r#"^org\.wezfurlong\.wezterm$"#
        default-column-width {}
    }

    // Open the Firefox picture-in-picture player as floating by default.
    window-rule {
        match app-id=r#"firefox$"# title="^Picture-in-Picture$"
        open-floating true
    }

    // Rounded corners for all windows.
    window-rule {
        geometry-corner-radius 10
        clip-to-geometry true
    }

    // Dim inactive windows slightly so the active window stands out by
    // contrast rather than a bright border.
    window-rule {
        match is-focused=false
        opacity 0.65
    }

    ${gamingConfig}

    binds {
        Mod+Shift+Slash { show-hotkey-overlay; }

        // Terminal — Mod+Enter (replaces default Mod+T)
        Mod+Return hotkey-overlay-title="Open a Terminal: kitty" { spawn "kitty"; }
        // Launcher — Mod+Space (replaces default Mod+D)
        Mod+Space hotkey-overlay-title="Run an Application: noctalia launcher" { spawn "noctalia" "msg" "panel-toggle" "launcher"; }
        Super+Alt+L hotkey-overlay-title="Lock the Screen: Noctalia" { spawn "noctalia" "msg" "session" "lock"; }

        Super+Alt+S allow-when-locked=true hotkey-overlay-title=null { spawn-sh "pkill orca || exec orca"; }

        XF86AudioRaiseVolume allow-when-locked=true { spawn-sh "wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.1+ -l 1.0"; }
        XF86AudioLowerVolume allow-when-locked=true { spawn-sh "wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.1-"; }
        XF86AudioMute        allow-when-locked=true { spawn-sh "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"; }
        XF86AudioMicMute     allow-when-locked=true { spawn-sh "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"; }

        XF86AudioPlay        allow-when-locked=true { spawn-sh "playerctl play-pause"; }
        XF86AudioPause       allow-when-locked=true { spawn-sh "playerctl play-pause"; }
        XF86AudioStop        allow-when-locked=true { spawn-sh "playerctl stop"; }
        XF86AudioPrev        allow-when-locked=true { spawn-sh "playerctl previous"; }
        XF86AudioNext        allow-when-locked=true { spawn-sh "playerctl next"; }

        XF86MonBrightnessUp allow-when-locked=true { spawn "brightnessctl" "--class=backlight" "set" "+10%"; }
        XF86MonBrightnessDown allow-when-locked=true { spawn "brightnessctl" "--class=backlight" "set" "10%-"; }

        Mod+O repeat=false { toggle-overview; }

        Mod+Q repeat=false { close-window; }

        Mod+Left  { focus-column-left; }
        Mod+Down  { focus-window-down; }
        Mod+Up    { focus-window-up; }
        Mod+Right { focus-column-right; }
        Mod+H     { focus-column-left; }
        Mod+J     { focus-window-down; }
        Mod+K     { focus-window-up; }
        Mod+L     { focus-column-right; }

        Mod+Ctrl+Left  { move-column-left; }
        Mod+Ctrl+Down  { move-window-down; }
        Mod+Ctrl+Up    { move-window-up; }
        Mod+Ctrl+Right { move-column-right; }
        Mod+Ctrl+H     { move-column-left; }
        Mod+Ctrl+J     { move-window-down; }
        Mod+Ctrl+K     { move-window-up; }
        Mod+Ctrl+L     { move-column-right; }

        Mod+Home { focus-column-first; }
        Mod+End  { focus-column-last; }
        Mod+Ctrl+Home { move-column-to-first; }
        Mod+Ctrl+End  { move-column-to-last; }

        Mod+Shift+Left  { focus-monitor-left; }
        Mod+Shift+Down  { focus-monitor-down; }
        Mod+Shift+Up    { focus-monitor-up; }
        Mod+Shift+Right { focus-monitor-right; }
        Mod+Shift+H     { focus-monitor-left; }
        Mod+Shift+J     { focus-monitor-down; }
        Mod+Shift+K     { focus-monitor-up; }
        Mod+Shift+L     { focus-monitor-right; }

        Mod+Shift+Ctrl+Left  { move-column-to-monitor-left; }
        Mod+Shift+Ctrl+Down  { move-column-to-monitor-down; }
        Mod+Shift+Ctrl+Up    { move-column-to-monitor-up; }
        Mod+Shift+Ctrl+Right { move-column-to-monitor-right; }
        Mod+Shift+Ctrl+H     { move-column-to-monitor-left; }
        Mod+Shift+Ctrl+J     { move-column-to-monitor-down; }
        Mod+Shift+Ctrl+K     { move-column-to-monitor-up; }
        Mod+Shift+Ctrl+L     { move-column-to-monitor-right; }

        Mod+Page_Down      { focus-workspace-down; }
        Mod+Page_Up        { focus-workspace-up; }
        Mod+U              { focus-workspace-down; }
        Mod+I              { focus-workspace-up; }
        Mod+Ctrl+Page_Down { move-column-to-workspace-down; }
        Mod+Ctrl+Page_Up   { move-column-to-workspace-up; }
        Mod+Ctrl+U         { move-column-to-workspace-down; }
        Mod+Ctrl+I         { move-column-to-workspace-up; }

        Mod+Shift+Page_Down { move-workspace-down; }
        Mod+Shift+Page_Up   { move-workspace-up; }
        Mod+Shift+U         { move-workspace-down; }
        Mod+Shift+I         { move-workspace-up; }

        Mod+WheelScrollDown      cooldown-ms=150 { focus-workspace-down; }
        Mod+WheelScrollUp        cooldown-ms=150 { focus-workspace-up; }
        Mod+Ctrl+WheelScrollDown cooldown-ms=150 { move-column-to-workspace-down; }
        Mod+Ctrl+WheelScrollUp   cooldown-ms=150 { move-column-to-workspace-up; }

        Mod+WheelScrollRight      { focus-column-right; }
        Mod+WheelScrollLeft       { focus-column-left; }
        Mod+Ctrl+WheelScrollRight { move-column-right; }
        Mod+Ctrl+WheelScrollLeft  { move-column-left; }

        Mod+Shift+WheelScrollDown      { focus-column-right; }
        Mod+Shift+WheelScrollUp        { focus-column-left; }
        Mod+Ctrl+Shift+WheelScrollDown { move-column-right; }
        Mod+Ctrl+Shift+WheelScrollUp   { move-column-left; }

        Mod+1 { focus-workspace 1; }
        Mod+2 { focus-workspace 2; }
        Mod+3 { focus-workspace 3; }
        Mod+4 { focus-workspace 4; }
        Mod+5 { focus-workspace 5; }
        Mod+6 { focus-workspace 6; }
        Mod+7 { focus-workspace 7; }
        Mod+8 { focus-workspace 8; }
        Mod+9 { focus-workspace 9; }
        Mod+Ctrl+1 { move-column-to-workspace 1; }
        Mod+Ctrl+2 { move-column-to-workspace 2; }
        Mod+Ctrl+3 { move-column-to-workspace 3; }
        Mod+Ctrl+4 { move-column-to-workspace 4; }
        Mod+Ctrl+5 { move-column-to-workspace 5; }
        Mod+Ctrl+6 { move-column-to-workspace 6; }
        Mod+Ctrl+7 { move-column-to-workspace 7; }
        Mod+Ctrl+8 { move-column-to-workspace 8; }
        Mod+Ctrl+9 { move-column-to-workspace 9; }

        Mod+BracketLeft  { consume-or-expel-window-left; }
        Mod+BracketRight { consume-or-expel-window-right; }

        Mod+Comma  { consume-window-into-column; }
        Mod+Period { expel-window-from-column; }

        Mod+R { switch-preset-column-width; }
        Mod+Shift+R { switch-preset-column-width-back; }

        Mod+Ctrl+Shift+R { switch-preset-window-height; }
        Mod+Ctrl+R { reset-window-height; }

        Mod+F { maximize-column; }
        Mod+Shift+F { fullscreen-window; }

        Mod+M { maximize-window-to-edges; }

        Mod+Ctrl+F { expand-column-to-available-width; }

        Mod+C { center-column; }

        Mod+Ctrl+C { center-visible-columns; }

        Mod+Minus { set-column-width "-10%"; }
        Mod+Equal { set-column-width "+10%"; }

        Mod+Shift+Minus { set-window-height "-10%"; }
        Mod+Shift+Equal { set-window-height "+10%"; }

        Mod+V       { toggle-window-floating; }
        Mod+Shift+V { switch-focus-between-floating-and-tiling; }

        Mod+W { toggle-column-tabbed-display; }

        Print { screenshot; }
        Ctrl+Print { screenshot-screen; }
        Alt+Print { screenshot-window; }

        Mod+Escape allow-inhibiting=false { toggle-keyboard-shortcuts-inhibit; }

        Mod+Shift+E { quit; }
        Ctrl+Alt+Delete { quit; }

        Mod+Shift+P { power-off-monitors; }
    }
  '';

  home.packages = [
    pkgs.xwayland-satellite
  ]
  ++ lib.optionals isConvertible [
    oskStart
    oskKill
  ];

  gtk = {
    enable = true;

    # adw-gtk3 is highly recommended for a consistent modern dark look,
    # but you could also use "Arc-Dark", "Dracula", etc.
    theme = {
      name = "adw-gtk3-dark";
      package = pkgs.adw-gtk3;
    };

    iconTheme = {
      name = "Adwaita";
      package = pkgs.adwaita-icon-theme;
    };

    # Forces older GTK3 and GTK4 apps to prefer dark variants
    gtk3.extraConfig = {
      gtk-application-prefer-dark-theme = 1;
    };
    gtk4.extraConfig = {
      gtk-application-prefer-dark-theme = 1;
    };
  };

  # Tells modern desktop apps (like Firefox or Libadwaita apps)
  # via XDG Desktop Portals that you prefer dark mode.
  dconf.settings = {
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
    };
  };
}
