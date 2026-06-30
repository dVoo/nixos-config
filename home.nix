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
    ./modules/noctalia.nix
    ./modules/lazyvim.nix
    ./modules/niri.nix
  ];

  home.username = "daniel";
  home.homeDirectory = "/home/daniel";
  home.stateVersion = "25.11";

  programs.home-manager.enable = true;

  home.sessionVariables = {
    OPENCODE_EXPERIMENTAL_BACKGROUND_SUBAGENTS = true;
    OLLAMA_API_KEY = "$(cat ${config.age.secrets.ollama-api-key.path})";
    OPENROUTER_API_KEY = "$(cat ${config.age.secrets.openrouter-api-key.path})";
  };

  home.packages = with pkgs; [
    font-awesome
    inputs.zen-browser.packages.${pkgs.system}.default
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
    hyprpolkitagent
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

    wireplumber
    btop
    wl-clipboard
    brightnessctl
    gvfs
    playerctl
    libnotify

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
    defaultEditor = false; # LazyVim is now the default editor
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
}
