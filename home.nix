{
  config,
  pkgs,
  pkgs-unstable,
  inputs,
  ...
}:

{
  # Secrets
  age.secrets.weather-api-key = {
    file = ./secrets/weather-api-key.age;
    name = "weather-api-key.json";
    path = "/run/user/1000/agenix/weather-api-key.json";
  };

  imports = [
    ./modules/hyprland.nix
    ./modules/hyprpanel.nix
  ];

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

  systemd.user.services.swww-random-wallpaper = {
    Unit = {
      Description = "Random wallpaper changer for swww";
      After = [ "swww.service" ];
      Wants = [ "swww.service" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${pkgs.writeShellScript "random-wallpaper-changer" ''
        #!/usr/bin/env bash
        set -euo pipefail

        WALLPAPER_DIR="${config.home.homeDirectory}/.wallpapers"

        mapfile -t wallpapers < <(find "$WALLPAPER_DIR" -type f \\( \\
          -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o \\
          -iname "*.gif" -o -iname "*.webp" -o -iname "*.avif" \\) 2>/dev/null)

        if [ ''${#wallpapers[@]} -eq 0 ]; then
          echo "No supported wallpapers found in $WALLPAPER_DIR"
          exit 1
        fi

        echo "Found ''${#wallpapers[@]} wallpapers. Starting rotation..."

        # Shuffle once for full cycle without repetition
        printf '%s\n' "''${wallpapers[@]}" | shuf | mapfile -t wallpapers

        while true; do
          for wallpaper in "''${wallpapers[@]}"; do
            [ -f "$wallpaper" ] || continue
            
            swww img "$wallpaper" \\
              --transition-type random \\
              --transition-fps 30 \\
              --transition-step 2
            
            sleep 300
          done
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

  # Automount
  services.udiskie = {
    enable = true;
    automount = true;
    tray = "auto";
  };

  # Secrets
  age.secrets.kubeconfig = {
    file = ./secrets/kubeconfig.age;
    path = "${config.home.homeDirectory}/.kube/config";
    mode = "600";
  };
}
