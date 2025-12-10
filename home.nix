{
  config,
  pkgs,
  pkgs-unstable,
  inputs,
  osConfig,
  ...
}:

let
  hostname = osConfig.networking.hostName;
in
{
  home.username = "daniel";
  home.homeDirectory = "/home/daniel";
  home.stateVersion = "25.11";

  programs.home-manager.enable = true;

  home.packages = with pkgs; [
    font-awesome
    rofi
    swww
    fd
    ripgrep
    fzf
    grc
    htop
    neofetch
    google-chrome
    kubectl
    jujutsu
    k9s
    bibata-cursors
    superfile
    hyprlock
    hyprpolkitagent

    #fish
    fishPlugins.z
    fishPlugins.tide
    fishPlugins.grc
    fishPlugins.fzf-fish
    fishPlugins.forgit

    #programming
    go

    ##langservers
    nil
    ty
    ruff
    gopls
    delve

    #hyprpanel
    wireplumber
    upower
    bluez
    bluez-tools
    grimblast
    hyprpicker
    btop
    networkmanager
    wl-clipboard
    brightnessctl
    gnome-bluetooth
    gvfs
    nodejs
    gtksourceview3
    swww
    matugen
    playerctl
  ];

  # Secrets
  age.secrets.weather-api-key = {
    file = ./secrets/weather-api-key.age;
    name = "weather-api-key.json";
    path = "/run/user/1000/agenix/weather-api-key.json";
  };

  # Hyprland with official module
  wayland.windowManager.hyprland = {
    enable = true;
    systemd.enable = true;
    extraConfig = ''
      source = ~/.localconfig/hyprland/hyprland.conf
      source = ~/.localconfig/hyprland/hyprland_host_${hostname}.conf
    '';
  };

  # home.file.".config/hyprpanel/config.json".source =
  #   "${config.home.homeDirectory}/.localconfig/hyprpanel/config.json";
  xdg.configFile.".wallpapers" = {
    source = "${config.home.homeDirectory}/.localconfig/wallpapers";
    recursive = true;
  };

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

  # Terminal
  programs.kitty = {
    enable = true;
    font.name = "FiraCode Nerd Font";
    font.size = 12;
    settings = {
      confirm_os_window_close = 0;
      background_opacity = "0.9";
      background_blur = "5";
      enable_audio_bell = false;
    };
  };

  # Shell
  programs.bash.enable = false;
  programs.fish = {
    enable = true;
    shellAliases = {
      ll = "ls -lah";
      rebuild = "sudo nixos-rebuild switch --flake ~/nixos-config --impure";
      update = "nix flake update ~/nixos-config";
      gc = "nix-collect-garbage -d";
    };
    plugins = [
      {
        name = "grc";
        src = pkgs.fishPlugins.grc.src;
      }
      {
        name = "z";
        src = pkgs.fishPlugins.z.src;
      }
      {
        name = "tide";
        src = pkgs.fishPlugins.tide.src;
      }
      {
        name = "fzf-fish";
        src = pkgs.fishPlugins.fzf-fish.src;
      }
      {
        name = "forgit";
        src = pkgs.fishPlugins.forgit.src;
      }
    ];
  };

  # Helix
  programs.helix = {
    enable = true;
    defaultEditor = true; # Sets EDITOR=hx for the user session
    settings = {
      theme = "focus_nova";
      editor = {
        line-number = "relative";
        end-of-line-diagnostics = "hint";
        inline-diagnostics.cursor-line = "error";
        cursor-shape = {
          insert = "bar";
          normal = "block";
          select = "underline";
        };
        auto-format = true;
      };
    };
  };

  # Git
  programs.git = {
    enable = true;
    settings = {
      init.defaultBranch = "main";
      pull.rebase = false;
    };
    settings.user = {
      name = "Daniel Vollrath";
      email = "daniel@danielvollrath.de";
    };
  };

  home.pointerCursor = {
    gtk.enable = true;
    x11.enable = true;
    name = "Bibata-Modern-Classic";
    package = pkgs.bibata-cursors;
    size = 24;
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

  systemd.user.services.swww = {
    Unit = {
      Description = "swww Wayland wallpaper daemon";
      After = [ "graphical-session-pre.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${pkgs.swww}/bin/swww-daemon";
      Restart = "on-failure";
      RestartSec = 1;
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };

  systemd.user.services.swww-random-gif = {
    Unit = {
      Description = "Random GIF wallpaper changer for swww";
      After = [ "swww.service" ];
      Wants = [ "swww.service" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${pkgs.writeShellScript "random-gif-changer" ''
        WALLPAPER_DIR="${config.home.homeDirectory}/.wallpapers"

        while true; do
          random_gif=$(ls "$WALLPAPER_DIR"/*.gif 2>/dev/null | shuf -n 1)
          [ -n "$random_gif" ] || { sleep 60; continue; }

          swww img "$random_gif" \
            --transition-type random \
            --transition-fps 30 \
            --transition-step 2

          sleep 300
        done
      ''}";
      Restart = "always";
      RestartSec = 5;
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };

  # XDG defaults
  xdg.enable = true;
  xdg.userDirs.enable = true;
  xdg.userDirs = {
    download = "${config.home.homeDirectory}/Downloads";
    desktop = "${config.home.homeDirectory}/Desktop";
    documents = "${config.home.homeDirectory}/Documents";
    music = "${config.home.homeDirectory}/Music";
    pictures = "${config.home.homeDirectory}/Pictures";
    videos = "${config.home.homeDirectory}/Videos";
  };

  # Secrets
  age.secrets.kubeconfig = {
    file = ./secrets/kubeconfig.age;
    path = "${config.home.homeDirectory}/.kube/config";
    mode = "600";
  };
}
