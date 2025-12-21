{
  config,
  pkgs,
  osConfig,
  lib,
  ...
}:

let
  hostname = osConfig.networking.hostName;
  # hyprland-settings.nix

  baseSettings = {
    # Monitor configuration
    monitor = ",preferred,auto,1";

    # Programs
    "$terminal" = "kitty";
    "$fileManager" = "superfile";
    "$menu" = "rofi -combi-modi window,drun,ssh -theme docu -show combi -show-icons";
    "$mainMod" = "SUPER";

    # Autostart
    exec-once = [
      "agent-polkit"
      "swww img ~/.wallpapers/sunset_live.gif --transition-type wipe --transition-duration 2"
      "hyprctl setcursor Bibata-Modern-Classic 24"
    ];

    # Environment variables
    env = [
      "XCURSOR_SIZE,32"
      "HYPRCURSOR_SIZE,32"
      "EDITOR,hx"
    ];

    # General settings
    general = {
      gaps_in = 5;
      gaps_out = 10;
      border_size = 1;
      "col.active_border" = "rgba(a93f55ee) rgba(f2545bee) 45deg";
      "col.inactive_border" = "rgba(595959aa)";
      resize_on_border = false;
      allow_tearing = true;
      layout = "dwindle";
    };

    # Decoration
    decoration = {
      rounding = 10;
      active_opacity = 0.96;
      inactive_opacity = 0.9;

      shadow = {
        enabled = true;
        range = 4;
        render_power = 3;
        color = "rgba(1a1a1aee)";
      };

      blur = {
        enabled = true;
        size = 3;
        passes = 1;
        vibrancy = 0.1696;
      };
    };

    # Animations
    animations = {
      enabled = true;

      bezier = [
        "easeOutQuint,0.23,1,0.32,1"
        "easeInOutCubic,0.65,0.05,0.36,1"
        "linear,0,0,1,1"
        "almostLinear,0.5,0.5,0.75,1.0"
        "quick,0.15,0,0.1,1"
      ];

      animation = [
        "global, 1, 10, default"
        "border, 1, 5.39, easeOutQuint"
        "windows, 1, 4.79, easeOutQuint"
        "windowsIn, 1, 4.1, easeOutQuint, popin 87%"
        "windowsOut, 1, 1.49, linear, popin 87%"
        "fadeIn, 1, 1.73, almostLinear"
        "fadeOut, 1, 1.46, almostLinear"
        "fade, 1, 3.03, quick"
        "layers, 1, 3.81, easeOutQuint"
        "layersIn, 1, 4, easeOutQuint, fade"
        "layersOut, 1, 1.5, linear, fade"
        "fadeLayersIn, 1, 1.79, almostLinear"
        "fadeLayersOut, 1, 1.39, almostLinear"
        "workspaces, 1, 1.94, almostLinear, fade"
        "workspacesIn, 1, 1.21, almostLinear, fade"
        "workspacesOut, 1, 1.94, almostLinear, fade"
      ];
    };

    # Dwindle layout
    dwindle = {
      pseudotile = true;
      preserve_split = true;
    };

    # Master layout
    master = {
      new_status = "master";
    };

    # Misc settings
    misc = {
      force_default_wallpaper = 0;
      disable_hyprland_logo = true;
    };

    # Input settings
    input = {
      kb_layout = "us";
      kb_variant = "altgr-intl";
      kb_options = "caps:escape";
      follow_mouse = 1;
      sensitivity = 0;

      touchpad = {
        natural_scroll = true;
      };
    };

    # Device-specific settings
    device = {
      name = "epic-mouse-v1";
      sensitivity = -0.5;
    };

    # Keybindings
    bind = [
      # Launch applications
      "$mainMod, Q, exec, $terminal"
      "$mainMod, Return, exec, $terminal"
      "$mainMod, C, killactive,"
      "$mainMod, M, exit,"
      "$mainMod, E, exec, $terminal $fileManager"
      "$mainMod SHIFT, V, togglefloating,"
      "$mainMod, R, exec, $menu"
      "$mainMod, Space, exec, $menu"
      "$mainMod, P, pseudo,"
      "$mainMod, T, togglesplit,"
      "$mainMod, F, fullscreen, 0"
      "$mainMod, O, exec, hyprshot -m region"
      "$mainMod, V, exec, cliphist list | rofi -dmenu | cliphist decode | wl-copy"

      # Move focus
      "$mainMod, H, movefocus, l"
      "$mainMod, L, movefocus, r"
      "$mainMod, K, movefocus, u"
      "$mainMod, J, movefocus, d"

      # Switch workspaces
      "$mainMod, 1, workspace, 1"
      "$mainMod, 2, workspace, 2"
      "$mainMod, 3, workspace, 3"
      "$mainMod, 4, workspace, 4"
      "$mainMod, 5, workspace, 5"
      "$mainMod, 6, workspace, 6"
      "$mainMod, 7, workspace, 7"
      "$mainMod, 8, workspace, 8"
      "$mainMod, 9, workspace, 9"
      "$mainMod, 0, workspace, 10"

      # Move windows to workspaces
      "$mainMod SHIFT, 1, movetoworkspace, 1"
      "$mainMod SHIFT, 2, movetoworkspace, 2"
      "$mainMod SHIFT, 3, movetoworkspace, 3"
      "$mainMod SHIFT, 4, movetoworkspace, 4"
      "$mainMod SHIFT, 5, movetoworkspace, 5"
      "$mainMod SHIFT, 6, movetoworkspace, 6"
      "$mainMod SHIFT, 7, movetoworkspace, 7"
      "$mainMod SHIFT, 8, movetoworkspace, 8"
      "$mainMod SHIFT, 9, movetoworkspace, 9"
      "$mainMod SHIFT, 0, movetoworkspace, 10"

      # Special workspace
      "$mainMod, S, togglespecialworkspace, magic"
      "$mainMod SHIFT, S, movetoworkspace, special:magic"

      # Scroll through workspaces
      "$mainMod, mouse_down, workspace, e+1"
      "$mainMod, mouse_up, workspace, e-1"
    ];

    # Mouse bindings
    bindm = [
      "$mainMod, mouse:272, movewindow"
      "$mainMod, mouse:273, resizewindow"
    ];

    # Media key bindings
    bindel = [
      ",XF86AudioRaiseVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"
      ",XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
      ",XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
      ",XF86AudioMicMute, exec, wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"
      ",XF86MonBrightnessUp, exec, brightnessctl set 10%+"
      ",XF86MonBrightnessDown, exec, brightnessctl set 10%-"
    ];

    bindl = [
      ", XF86AudioNext, exec, playerctl next"
      ", XF86AudioPause, exec, playerctl play-pause"
      ", XF86AudioPlay, exec, playerctl play-pause"
      ", XF86AudioPrev, exec, playerctl previous"
    ];

    # Window rules
    windowrulev2 = [
      #"suppressevent maximize, class:.*"
      "nofocus,class:^$,title:^$,xwayland:1,floating:1,fullscreen:0,pinned:0"
      "opacity 1.0 override,fullscreen:0"
      "opacity 1.0 override,fullscreen:1"
      "opacity 1.0 override,fullscreen:2"
      "opacity 1.0 override,class:^(google-chrome)$"
      "opacity 1.0 override,class:^(Gimp-.*)$"
      "opacity 1.0 override,class:^(kitty)$"
      "immediate, class:^(gamescope)$"
      "immediate, class:^(steam_app_\\d+)$"
    ];
  };

  # Host-specific settings
  notebookSettings = {
    decoration = {
      blur.enabled = false;
      shadow.enabled = false;
    };
    misc.vfr = true;
    xwayland = {
      force_zero_scaling = true;
      enabled = true;
    };
  };

  pcSettings = {
    monitor = [
      "DP-1, highres@highrr, auto, 1"
      "DP-2, highres@highrr, auto-left, 1"
    ];

    workspace = [
      "1, monitor:DP-1"
      "2, monitor:DP-1"
      "3, monitor:DP-1"
      "4, monitor:DP-1"
      "5, monitor:DP-1"
      "6, monitor:DP-1"
      "7, monitor:DP-2"
      "8, monitor:DP-2"
      "1, monitor:DP-1, default:true"
      "7, monitor:DP-2, default:true"
      "5, monitor:DP-1"
    ];

    windowrulev2 = [
        "immediate, fullscreen:2"                    # Add immediate for exclusive fullscreen
        "workspace 5, class:^(gamescope)(.*)$"
        "workspace 5, class:^(steam_app_\\d+)$"
    ];

    misc = {
      vfr = true;
      vrr = 2;
      allow_session_lock_restore = true;
    };

    xwayland.enabled = true;

    device = {
      name = "kingsis-peripherals-zowie-gaming-mouse";
      sensitivity = -0.3;
      accel_profile = "flat";
    };
  };

  # Merge host-specific settings with base settings
  hostSpecificSettings =
    if hostname == "pc" then
      pcSettings
    else if hostname == "hp15" then
      notebookSettings
    else if hostname == "xps" then
      notebookSettings
    else
      { };
in
{
  wayland.windowManager.hyprland = {
    enable = true;
    xwayland.enable = true;

    settings =
      let
        merged = lib.recursiveUpdate baseSettings hostSpecificSettings;
      in
      merged
      // {
        windowrulev2 = (baseSettings.windowrulev2 or [ ]) ++ (hostSpecificSettings.windowrulev2 or [ ]);
        exec-once = (baseSettings.exec-once or [ ]) ++ (hostSpecificSettings.exec-once or [ ]);
      };
  };

  # Hypridle
  services.hypridle = {
    enable = true;
    settings = {
      general = {
        lock_cmd = "pidof hyprlock || ${pkgs.hyprlock}/bin/hyprlock";
        before_sleep_cmd = "loginctl lock-session";
        after_sleep_cmd = "${pkgs.hyprland}/bin/hyprctl dispatch dpms on";
      };

      listener = [
        {
          timeout = 150;
          on-timeout = "${pkgs.brightnessctl}/bin/brightnessctl -s set 10";
          on-resume = "${pkgs.brightnessctl}/bin/brightnessctl -r";
        }
        {
          timeout = 150;
          on-timeout = "${pkgs.brightnessctl}/bin/brightnessctl -sd rgb:kbd_backlight set 0";
          on-resume = "${pkgs.brightnessctl}/bin/brightnessctl -rd rgb:kbd_backlight";
        }
        {
          timeout = 300;
          on-timeout = "loginctl lock-session";
        }
        {
          timeout = 330;
          on-timeout = "${pkgs.hyprland}/bin/hyprctl dispatch dpms off";
          on-resume = "${pkgs.hyprland}/bin/hyprctl dispatch dpms on && ${pkgs.brightnessctl}/bin/brightnessctl -r";
        }
        {
          timeout = 1800;
          on-timeout = "systemctl suspend";
        }
      ];
    };
  };
}
