{ config, ... }:
{
  programs.noctalia = {
    enable = true;
    systemd.enable = true;
    settings = {
      bar.default = {
        background_opacity = 0.34;
        capsule = true;
        center = [ "clock" "weather" ];
        end = [
          "cpu"
          "ram"
          "tray"
          "clipboard"
          "network"
          "bluetooth"
          "volume"
          "brightness"
          "battery"
          "power_profile"
          "control-center"
          "notifications"
        ];
        font_family = "FiraCode Nerd Font Mono";
        font_weight = 400;
        margin_edge = 4;
        margin_ends = 12;
        radius = 10;
        start = [ "launcher" "wallhaven" "taskbar" "active_window" ];
        thickness = 38;
        widget_spacing = 6;
      };

      brightness = {
        minimum_brightness = 0.01;
      };

      idle = {
        pre_action_fade_seconds = 2.0;
        behavior = {
          dim = {
            timeout = 150;
            action = "command";
            command = "brightnessctl set 10% && brightnessctl -d '*::kbd_backlight' set 0";
            resume_command = "brightnessctl set 100% && brightnessctl -d '*::kbd_backlight' set 2";
          };
          lock = {
            timeout = 300;
            action = "lock";
            enabled = true;
          };
          "screen-off" = {
            timeout = 450;
            action = "screen_off";
            enabled = true;
          };
        };
      };

      location = {
        auto_locate = true;
      };

      lockscreen = {
        enabled = true;
        blurred_desktop = true;
        blur_intensity = 0.5;
        tint_intensity = 0.3;
      };

      lockscreen_widgets = {
        enabled = false;
        schema_version = 2;
        # NOTE: widget_order + widget config below are hardcoded for a 1080p eDP-1
        # panel (notebooks). Adjust output + coordinates before enabling on pc
        # (dual DP monitors, no eDP-1).
        widget_order = [ "lockscreen-login-box@eDP-1" ];

        grid = {
          cell_size = 16;
          major_interval = 4;
          visible = true;
        };

        widget."lockscreen-login-box@eDP-1" = {
          box_height = 70.0;
          box_width = 400.0;
          cx = 960.0;
          cy = 961.0;
          output = "eDP-1";
          rotation = 0.0;
          type = "login_box";

          settings = {
            background_color = "surface_variant";
            background_opacity = 0.88;
            background_radius = 12.0;
            input_opacity = 1.0;
            input_radius = 6.0;
            show_login_button = true;
          };
        };
      };

      plugins = {
        enabled = [ "noctalia/wallhaven" ];
      };

      shell = {
        screenshot = {
          save_to_file = true;
          directory = "";
          filename_pattern = "screenshot_%Y%m%d_%H%M%S";
          copy_to_clipboard = true;
          freeze_screen = false;
          confirm_region = false;
        };
      };

      theme = {
        community_palette = "GitHub Dark";
        source = "community";
      };

      widget.taskbar = {
        group_by_workspace = true;
        scale = 1.2;
        workspace_label_placement = "corner";
      };

      widget.wallhaven = {
        type = "noctalia/wallhaven:wallhaven";
      };
    };
  };
}
