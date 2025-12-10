{ config, pkgs, ... }:
{
  # Hyprpanel
  programs.hyprpanel = {
    enable = true;

    settings = {
      bar = {
        autoHide = "fullscreen";
        customModules = {
          storage = {
            paths = [ "/" ];
          };
        };
        launcher = {
          autoDetectIcon = true;
        };
        layouts = {
          "0" = {
            left = [
              "dashboard"
              "workspaces"
              "windowtitle"
            ];
            middle = [ "weather" ];
            right = [
              "volume"
              "network"
              "bluetooth"
              "battery"
              "systray"
              "cpu"
              "ram"
              "clock"
              "notifications"
            ];
          };
          "1" = {
            left = [
              "dashboard"
              "workspaces"
              "windowtitle"
            ];
            middle = [ "media" ];
            right = [
              "volume"
              "clock"
              "notifications"
            ];
          };
          "2" = {
            left = [
              "dashboard"
              "workspaces"
              "windowtitle"
            ];
            middle = [ "media" ];
            right = [
              "volume"
              "clock"
              "notifications"
            ];
          };
        };
        network = {
          showWifiInfo = true;
          truncation_size = 25;
        };
        bluetooth = {
          label = true;
        };
        clock = {
          format = "%a %d %b  %H:%M:%S";
        };
        notifications = {
          show_total = true;
        };
        workspaces = {
          show_icons = false;
          show_numbered = false;
          workspaceMask = false;
          showWsIcons = true;
          showApplicationIcons = true;
        };
      };

      theme = {
        font = {
          size = "1.1rem";
          name = "Iosevka Nerd Font Propo";
          style = "normal";
          label = "Iosevka Nerd Font Propo Semi-Bold";
        };
        bar = {
          floating = true;
          location = "top";
          layer = "top";
          enableShadow = false;
          margin_top = "0.5em";
          margin_bottom = "0em";
          margin_sides = "0.5em";
          outer_spacing = "0.6em";
          menus = {
            menu = {
              network = {
                scaling = 100;
              };
              dashboard = {
                profile = {
                  size = "8.5em";
                };
                scaling = 100;
              };
            };
          };
          buttons = {
            enableBorders = false;
            y_margins = "0.4em";
            separator = {
              margins = "0.15em";
            };
            dashboard = {
              enableBorder = false;
            };
            windowtitle = {
              spacing = "1em";
            };
            modules = {
              ram = {
                spacing = "0.8em";
              };
              cpu = {
                spacing = "0.8em";
              };
            };
            padding_x = "0.6rem";
          };
        };
        matugen = false;
      };

      menus = {
        clock = {
          time = {
            military = true;
            hideSeconds = false;
          };
          weather = {
            location = "Bahrdorf";
            unit = "metric";
            key = config.age.secrets.weather-api-key.path;
          };
        };
        dashboard = {
          shortcuts = {
            enabled = false;
            left = {
              shortcut1 = {
                tooltip = "Google Chrome";
                command = "google-chrome";
              };
            };
          };
        };
        power = {
          lowBatteryNotification = true;
        };
      };
    };
  };
}
