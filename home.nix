{
  config,
  pkgs,
  inputs,
  ...
}:

{
  # Secrets
  age.secrets.kubeconfig = {
    file = ./secrets/kubeconfig.age;
    path = "${config.home.homeDirectory}/.kube/config";
    mode = "0400";
  };

  age.secrets.weather-api-key = {
    file = ./secrets/weather-api-key.age;
    name = "weather-api-key.json";
    path = "/run/user/1000/agenix/weather-api-key.json";
  };

  age.secrets.ollama-api-key = {
    file = ./secrets/ollama-api-key.age;
    mode = "0400";
  };

  age.secrets.openrouter-api-key = {
    file = ./secrets/openrouter-api-key.age;
    mode = "0400";
  };

  # Keyring
  services.gnome-keyring.enable = true;

  imports = [
    ./modules/hyprland.nix
    ./modules/hyprpanel.nix
  ];

  home.username = "daniel";
  home.homeDirectory = "/home/daniel";
  home.stateVersion = "25.11";

  programs.home-manager.enable = true;

  programs.firefox.enable = true;
  programs.firefox.configPath = "${config.xdg.configHome}/mozilla/firefox";

  home.sessionVariables = {
    OPENCODE_EXPERIMENTAL_BACKGROUND_SUBAGENTS = true;
    OLLAMA_API_KEY = "$(cat ${config.age.secrets.ollama-api-key.path})";
    OPENROUTER_API_KEY = "$(cat ${config.age.secrets.openrouter-api-key.path})";
  };

  home.packages = with pkgs; [
    font-awesome
    rofi
    awww
    fd
    jq
    ripgrep
    fzf
    gcr
    grc
    htop
    fastfetch
    (google-chrome.override {
      commandLineArgs = [
        # "--enable-features=AcceleratedVideoEncoder,VaapiOnNvidiaGPUs,VaapiIgnoreDriverChecks,Vulkan,DefaultANGLEVulkan,VulkanFromANGLE"
        # "--enable-features=VaapiIgnoreDriverChecks,VaapiVideoDecoder,PlatformHEVCDecoderSupport"
        # "--enable-features=UseMultiPlaneFormatForHardwareVideo"
        "--ignore-gpu-blocklist"
        "--enable-zero-copy"
      ];
    })
    kubectl
    jujutsu
    k9s
    kubernetes-helm
    bibata-cursors
    superfile
    hyprlock
    hyprpolkitagent
    hyprshot
    libreoffice
    zathura
    papers
    nautilus
    aichat
    glow
    tor-browser

    #programming
    go
    gcc
    gnumake
    binutils
    pkg-config
    pkgs.opencode
    patchelf

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
    matugen
    playerctl

    pkgs.proton-vpn-cli
    libnatpmp
    gimp
  ];

  # ProtonVPN port forward
  home.file.".local/bin/protonvpn-forward" = {
    text = ''
      #!/usr/bin/env bash
      while true ; do date ; natpmpc -a 1 0 udp 60 -g 10.2.0.1 && natpmpc -a 1 0 tcp 60 -g 10.2.0.1 || { echo -e "ERROR with natpmpc command \a" ; break ; } ; sleep 45 ; done
    '';
    executable = true;
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
    # plugins = [
    #   {
    #     name = "grc";
    #     src = pkgs.fishPlugins.grc.src;
    #   }
    #   {
    #     name = "z";
    #     src = pkgs.fishPlugins.z.src;
    #   }
    #   {
    #     name = "tide";
    #     src = pkgs.fishPlugins.tide.src;
    #   }
    #   {
    #     name = "fzf-fish";
    #     src = pkgs.fishPlugins.fzf-fish.src;
    #   }
    #   {
    #     name = "forgit";
    #     src = pkgs.fishPlugins.forgit.src;
    #   }
    # ];
    shellInit = ''
      fish_add_path -m ~/.local/bin
    '';
  };
  programs.starship.enable = true;

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

  systemd.user.services.awww = {
    Unit = {
      Description = "awww Wayland wallpaper daemon";
      After = [ "graphical-session-pre.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${pkgs.awww}/bin/awww-daemon";
      Restart = "on-failure";
      RestartSec = 1;
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };

  systemd.user.services.awww-random-wallpaper = {
    Unit = {
      Description = "Random wallpaper changer for awww";
      After = [ "awww.service" ];
      Wants = [ "awww.service" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${pkgs.writeShellScript "random-wallpaper-changer" ''
        #!/usr/bin/env bash
        set -euo pipefail

        WALLPAPER_DIR="${config.home.homeDirectory}/.wallpapers"

        # Collect ALL image files recursively using find with proper quoting
        mapfile -t wallpapers < <(find "$WALLPAPER_DIR" -type f '(' \
          -iname "*.jpg" -o \
          -iname "*.jpeg" -o \
          -iname "*.png" -o \
          -iname "*.gif" -o \
          -iname "*.webp" -o \
          -iname "*.avif" ')' -print 2>/dev/null || true)

        if [ ''${#wallpapers[@]} -eq 0 ]; then
          echo "No supported wallpapers found in $WALLPAPER_DIR"
          sleep infinity
        fi

        echo "Found ''${#wallpapers[@]} wallpapers. Starting rotation..."

        # Shuffle once for full cycle without repetition
        printf '%s\n' "''${wallpapers[@]}" | shuf | mapfile -t wallpapers

        while true; do
          for wallpaper in "''${wallpapers[@]}"; do
            [ -f "$wallpaper" ] || continue

            awww img "$wallpaper"

            sleep 1800
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
  xdg.userDirs.setSessionVariables = true;
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

  # Zed
  programs.zed-editor = {
    enable = true;
    package = pkgs.zed-editor;
    extensions = [ "nix" "toml" "go" ];
    userSettings = {
      helix_mode = true;
      auto_update = false; # important on NixOS — let Nix manage updates
      theme = {
        mode = "dark";
        dark = "Ayu Dark";
        light = "One Light";
      };
    };
  };

  # AI Config
  programs.aichat = {
    enable = true;
    settings = {
      clients = [
        {
          type = "openai-compatible";
          name = "ollama";
          api_base = "https://ollama.com/v1";
          models = [ { name = "glm-5.2:cloud"; max_input_tokens = 1000000; } ];
        }
      ];
    };
  };

  services.ollama.enable = false;
}
