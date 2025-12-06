{ config, pkgs, pkgs-unstable, inputs, ... }:

{
  home.username = "daniel";
  home.homeDirectory = "/home/daniel";
  home.stateVersion = "25.11";

  programs.home-manager.enable = true;

  # Hyprland with official module
  wayland.windowManager.hyprland = {
    enable = true;
    systemd.enable = true;
    settings = {
      "$mod" = "SUPER";
      
      bind = [
        "$mod, Return, exec, kitty"
        "$mod, D, exec, rofi -show drun"
        "$mod, Q, killactive"
        "$mod, F, fullscreen, 0"
        "$mod, V, togglefloating"
        "$mod, P, pseudo"
        "$mod, J, togglesplit"
      ];

      bindm = [
        "$mod, mouse:272, movewindow"
        "$mod, mouse:273, resizewindow"
      ];

      monitor = ",highres,auto,1";
      
      input = {
        kb_layout = "us";
        follow_mouse = 1;
        sensitivity = 0;
      };

      general = {
        gaps_in = 8;
        gaps_out = 12;
        border_size = 2;
        "col.active_border" = "0xff00d9ff";
        "col.inactive_border" = "0xff333333";
        layout = "dwindle";
      };

      decoration = {
        rounding = 8;
        blur.enabled = true;
        blur.size = 4;
        blur.passes = 2;
      };

      animations = {
        enabled = true;
        bezier = "myBezier, 0.05, 0.9, 0.1, 1.05";
        animation = [
          "windows, 1, 10, myBezier"
          "windowsOut, 1, 10, default, popin 80%"
          "border, 1, 10, default"
          "fade, 1, 7, default"
          "workspaces, 1, 6, default"
        ];
      };

      dwindle = {
        pseudotile = true;
        preserve_split = true;
      };
    };
  };

  # Waybar status bar
  programs.waybar = {
    enable = true;
    package = pkgs.waybar;
    settings = {
      mainBar = {
        layer = "top";
        position = "top";
        height = 30;
        modules-left = [ "hyprland/workspaces" ];
        modules-center = [ "hyprland/window" ];
        modules-right = [ "pulseaudio" "network" "cpu" "memory" "battery" "clock" ];
        
        "hyprland/workspaces" = {
          format = "{id}";
          on-click = "activate";
        };
        
        clock = {
          format = "{:%H:%M}";
          tooltip-format = "{:%Y-%m-%d}";
        };
        
        cpu = {
          format = "󰍛 {usage}%";
        };
        
        memory = {
          format = " {used}MB";
        };
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
  programs.fish= {
    enable = true;
    shellAliases = {
      ll = "ls -lah";
      rebuild = "sudo nixos-rebuild switch --flake ~/.config/nixos";
      update = "nix flake update ~/.config/nixos";
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
    rofi
    dunst
    swww
    fd
    ripgrep
    fzf
    htop
    neofetch
    kubectl
    k9s
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

