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
        // Dual-monitor desktop — native resolution and refresh rate are
        // auto-detected by niri when no `mode` is specified.
        // Layout matches Hyprland: [DP-2] [DP-1] (DP-2 left of DP-1).
        output "DP-1" {
            // KTC H26T22C — native 2560x1440; 180Hz is the highest available mode
            // (the monitor's preferred mode is only 59.951Hz, so it must be set explicitly).
            mode "2560x1440@180.000"
            scale 1.0
            variable-refresh-rate on-demand=true
        }
        // MSI G27CQ4 — VRR not supported by this panel, so it's omitted.
        output "DP-2" {
            scale 1.0
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

  # Lid switch + tablet mode events for laptops
  switchEventsConfig =
    if isConvertible then
      ''
        switch-events {
            lid-close { spawn "swaylock"; }
            lid-open { }
            tablet-mode-on {
                spawn "bash" "-c" "gsettings set org.gnome.desktop.a11y.applications screen-keyboard-enabled true"
            }
            tablet-mode-off {
                spawn "bash" "-c" "gsettings set org.gnome.desktop.a11y.applications screen-keyboard-enabled false"
            }
        }
      ''
    else if isLaptop then
      ''
        switch-events {
            lid-close { spawn "swaylock"; }
            lid-open { }
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

    window-rule {
        match app-id=r#"(?i)geforce.?now"#
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
            accel-profile "flat"
            accel-speed -0.3
        }

        trackpoint {
        }
    ${touchTabletConfig}
    }

    ${switchEventsConfig}

    // Settings that influence how windows are positioned and sized.
    layout {
        gaps 5
        center-focused-column "never"

        preset-column-widths {
            proportion 0.33333
            proportion 0.5
            proportion 0.66667
        }

        default-column-width { proportion 0.5; }

        focus-ring {
            width 3
            active-color "#7fc8ff"
            inactive-color "#505050"
        }

        border {
            off
            width 3
            active-color "#ffc87f"
            inactive-color "#505050"
            urgent-color "#9b0000"
        }

        shadow {
            softness 30
            spread 5
            offset x=0 y=5
            color "#0007"
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
        geometry-corner-radius 5
        clip-to-geometry true
    }

    ${gamingConfig}

    binds {
        Mod+Shift+Slash { show-hotkey-overlay; }

        // Terminal — Mod+Enter (replaces default Mod+T)
        Mod+Return hotkey-overlay-title="Open a Terminal: kitty" { spawn "kitty"; }
        // Launcher — Mod+Space (replaces default Mod+D)
        Mod+Space hotkey-overlay-title="Run an Application: noctalia launcher" { spawn "noctalia" "msg" "panel-toggle" "launcher"; }
        Super+Alt+L hotkey-overlay-title="Lock the Screen: swaylock" { spawn "swaylock"; }

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

  home.packages = [ pkgs.xwayland-satellite ];
}

