{ config, pkgs, pkgs-unstable, inputs, osConfig, ... }:

let
  hostname = osConfig.networking.hostName;
in
{
  home.username = "daniel";
  home.homeDirectory = "/home/daniel";
  home.stateVersion = "25.11";

  programs.home-manager.enable = true;

  # Hyprland with official module
  wayland.windowManager.hyprland = {
    enable = true;
    systemd.enable = true;
    extraConfig = ''
      source = ~/.localconfig/hyprland/hyprland.conf
      source = ~/.localconfig/hyprland/hyprland_host_${hostname}.conf
    '';
  };

  # programs.hyprpanel = {
  #   enable = true;
  #   systemd.enable = true;
  #   #hyprland.enable = true;
  #   settings = {
  #     # =====================================================================
  #     # LAYOUT CONFIGURATION
  #     # =====================================================================
      
  #     layout.bar.layouts."0" = {
  #       left = ["dashboard" "workspaces"];
  #       middle = ["window_title"];
  #       right = ["volume" "network" "bluetooth" "systray" "clock" "notifications"];
  #     };
      
  #     # =====================================================================
  #     # BAR CONFIGURATION
  #     # =====================================================================
      
  #     bar.location = "top";
  #     bar.margins = "8px 10px";
  #     bar.padding = "8px 10px";
  #     bar.fontSize = 11;
      
  #     # Launcher
  #     bar.launcher.autoDetectIcon = true;
  #     bar.launcher.label = "launch";
  #     bar.launcher.command = "rofi -show drun";
  #     bar.launcher.rightClick = "rofi -show run";
      
  #     # Workspaces - Tokyo Night style with neon colors
  #     bar.workspaces.show_icons = true;
  #     bar.workspaces.show_numbered = false;
  #     bar.workspaces.icon_maps = {
  #       "1" = { icon = "󰣇"; color = "#BB9AF7"; };    # Lavender
  #       "2" = { icon = "󰌍"; color = "#7AA2F7"; };    # Blue
  #       "3" = { icon = "󰣂"; color = "#F7768E"; };    # Pink
  #       "4" = { icon = "󰊢"; color = "#9ECE6A"; };    # Green
  #       "5" = { icon = "󰎦"; color = "#FF9E64"; };    # Orange
  #       "6" = { icon = "󰝚"; color = "#BB9AF7"; };    # Lavender
  #       "7" = { icon = "󰮯"; color = "#7AA2F7"; };    # Blue
  #       "8" = { icon = "󰙯"; color = "#F7768E"; };    # Pink
  #       "9" = { icon = "󰜴"; color = "#9ECE6A"; };    # Green
  #     };
      
  #     # Window title
  #     bar.window_title.label = true;
  #     bar.window_title.max_length = 40;
  #     bar.window_title.icon = true;
  #     bar.window_title.truncate = "…";
  #     bar.window_title.truncate_right = true;
      
  #     # Clock
  #     bar.clock.format = "%a %b %d | %H:%M";
      
  #     # Modules with labels
  #     bar.volume.label = true;
  #     bar.network.label = true;
  #     bar.bluetooth.label = true;
      
  #     # Button styling - Wave style for more dynamic look
  #     bar.buttons.style = "default";  # Try: "wave", "wave2" for more flair
  #     bar.buttons.monochrome = false;
  #     bar.buttons.tooltips = true;
  #     bar.buttons.tooltips_distance = 10;
      
  #     # Scroll behavior
  #     bar.scrollSpeed = 3;
  #     bar.spacing = "0.5em";
      
  #     # =====================================================================
  #     # MENU CONFIGURATION
  #     # =====================================================================
      
  #     # Clock settings
  #     menus.clock.time.military = false;
  #     menus.clock.time.hideSeconds = false;
      
  #     # Weather settings (optional)
  #     menus.clock.weather.enabled = false;
  #     menus.clock.weather.unit = "celsius";
  #     menus.clock.weather.refresh_interval = 600000;
      
  #     # Notifications
  #     menus.notifications.show_total = true;
  #     menus.notifications.position = "top right";
  #     menus.notifications.margin = "10px 10px";
      
  #     # OSD settings
  #     menus.osd.orientation = "vertical";
  #     menus.osd.position = "center";
  #     menus.osd.margin = "0px 0px";
  #     menus.osd.monitor = 0;
  #     menus.osd.radius = "12px";
      
  #     # Dashboard
  #     menus.dashboard.monitor = 0;
  #     menus.dashboard.margin = "10px 10px";
  #     menus.dashboard.stats.enable_gpu = true;
      
  #     # =====================================================================
  #     # OPTIONAL: DYNAMIC THEMING WITH MATUGEN
  #     # =====================================================================
      
  #     # Uncomment to enable wallpaper-based dynamic theming
  #     # matugen.enabled = true;
  #     # matugen.theme = "dark";
  #     # matugen.contrast = 0.0;  # Range: -1.0 to 1.0
  #     # matugen.useImage = true;
      
  #     matugen.enabled = false;

  #     # theme.bar = {
  #     #   background = "rgba(40, 40, 40, 0.90)";
  #     #   border_radius = "12px";
  #     #   border = "2px solid rgba(184, 187, 38, 0.3)";
  #     #   foreground = "#EBDBB2";
  #     #   text_color = "#EBDBB2";
  #     #   notification_icon_color = "#FB4934";
  #     #   separator_color = "rgba(102, 92, 84, 0.4)";
  
  #     #   buttons = {
  #     #     background = "rgba(60, 56, 54, 0.5)";
  #     #     foreground = "#EBDBB2";
  #     #     hover_bg = "rgba(184, 187, 38, 0.6)";
  #     #     hover_fg = "#EBDBB2";
  #     #     active_bg = "rgba(184, 187, 38, 0.7)";
  #     #     active_fg = "#282828";
  #     #   };
  
  #     #   volume = { background = "rgba(184, 187, 38, 0.2)"; foreground = "#B8BB26"; };
  #     #   network = { background = "rgba(131, 165, 152, 0.2)"; foreground = "#83A598"; };
  #     #   bluetooth = { background = "rgba(254, 128, 25, 0.2)"; foreground = "#FE8019"; };
  #     #   battery = { background = "rgba(184, 187, 38, 0.2)"; foreground = "#B8BB26"; };
  #     #   cpu = { background = "rgba(131, 165, 152, 0.2)"; foreground = "#83A598"; };
  #     #   ram = { background = "rgba(251, 73, 52, 0.2)"; foreground = "#FB4934"; };
  #     #   storage = { background = "rgba(214, 93, 14, 0.2)"; foreground = "#D65D0E"; };
  #     #   clock = { background = "rgba(131, 165, 152, 0.2)"; foreground = "#83A598"; };
  #     #   media = { background = "rgba(254, 128, 25, 0.2)"; foreground = "#FE8019"; };
  #     # };
  #   };
  # };
  programs.hyprpanel = {
    enable = true;
    settings = {
      layout = {
        bar.layouts = {
          "0" = {
            left = [ "dashboard" "workspaces" ];
            middle = [ "media" ];
            right = [ "volume" "systray" "notifications" ];
          };
        };
      };

      bar.launcher.autoDetectIcon = true;
      bar.workspaces.show_icons = true;

      menus.clock = {
        time = {
          military = true;
          hideSeconds = true;
        };
        weather.unit = "metric";
      };

      menus.dashboard.directories.enabled = false;
      menus.dashboard.stats.enable_gpu = true;

      theme.bar.transparent = true;

      theme.font = {
        name = "CaskaydiaCove NF";
        size = "12px";
      };
    };
  };

  # Terminal
  programs.kitty = {
    enable = true;
    font.name = "Monospace";
    font.size = 12;
    settings = {
      background_opacity = "0.9";
      enable_audio_bell = false;
    };
  };

  programs.bash.enable = false;

  # Shell
  programs.fish = {
    enable = true;
    shellAliases = {
      ll = "ls -lah";
      rebuild = "sudo nixos-rebuild switch --flake ~/nixos-config";
      update = "nix flake update ~/nixos-config";
      gc = "nix-collect-garbage -d";
    };
  };

  # Helix
  programs.helix = {
    enable = true;
    defaultEditor = true; # Sets EDITOR=hx for the user session
    settings = {
      theme = "catppuccin_mocha";
      editor = {
        line-number = "relative";
        cursor-shape = {
          insert = "bar";
          normal = "block";
          select = "underline";
        };
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

  home.packages = with pkgs; [
    font-awesome
    rofi
    mako
    swww
    fd
    ripgrep
    fzf
    htop
    neofetch
    google-chrome
    kubectl
    k9s

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
    power-profiles-daemon
    gvfs
    nodejs
    gtksourceview3
    swww
    matugen
    playerctl
  ];

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

