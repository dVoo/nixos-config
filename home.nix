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

  age.secrets.deepseek-api-key = {
    file = ./secrets/deepseek-api-key.age;
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
    DEEPSEEK_API_KEY = "$(cat ${config.age.secrets.deepseek-api-key.path})";
    PAGER = "moor";
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
    velero
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
    wvkbd
    bubblewrap
    eza
    bat
    moor
    lnav

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

  # oh-my-pi / omp-safe — bwrap sandbox wrapper for the user-managed binary.
  # The binary itself lives at ~/.local/bin/omp (NOT managed by home-manager;
  # it's a self-updating product owned upstream). It gets installed manually on
  # first use and updated by `omp update`, which writes to ~/.local/bin/omp
  # directly (the binary's install path is hardcoded). Use `omp-safe` from a
  # project dir to run the binary under the bwrap sandbox; use `omp` (or
  # `omp update`) directly when you need to bypass the sandbox.
  #   curl -fsSL -o ~/.local/bin/omp \
  #     https://github.com/can1357/oh-my-pi/releases/latest/download/omp-linux-x64
  #   chmod +x ~/.local/bin/omp
  home.file.".local/bin/omp-safe" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      set -euo pipefail

      PROJECT_DIR="$(pwd)"
      OMP_BIN="$(readlink -f "$HOME/.local/bin/omp")"
      OMP_BIN_DIR="$(dirname "$OMP_BIN")"

      mkdir -p "$HOME/.omp"

      exec bwrap \
        --ro-bind /nix /nix \
        --ro-bind /etc /etc \
        --ro-bind /usr /usr \
        --ro-bind-try /lib /lib \
        --ro-bind-try /lib64 /lib64 \
        --ro-bind-try /run/current-system /run/current-system \
        --ro-bind "$OMP_BIN_DIR" "$OMP_BIN_DIR" \
        --proc /proc \
        --dev /dev \
        --tmpfs /tmp \
        --bind "$HOME/.omp" "$HOME/.omp" \
        --bind "$PROJECT_DIR" "$PROJECT_DIR" \
        --unshare-pid --unshare-ipc --unshare-uts \
        --share-net \
        --die-with-parent \
        --chdir "$PROJECT_DIR" \
        --setenv HOME "$HOME" \
        "$OMP_BIN" "$@"
    '';
  };

  # Terminal
  programs.kitty = {
    enable = true;
    font.name = "FiraCode Nerd Font";
    font.size = 12;
    settings = {
      confirm_os_window_close = 0;
      background_opacity = "0.75";
      background_blur = "5";
      enable_audio_bell = false;
    };
  };
  programs.fish = {
    enable = true;
    shellAliases = {
      rebuild = "sudo nixos-rebuild switch --flake ~/nixos-config --impure";
      update = "nix flake update ~/nixos-config";
      gc = "nix-collect-garbage -d";
    };
    # Modern replacements for ls, cat, less/more; omp alias to the bwrap
    # sandbox wrapper so an unqualified `omp` runs the user-managed binary
    # under bwrap. The raw binary at ~/.local/bin/omp stays free for explicit
    # invocations like `~/.local/bin/omp update`.
    shellAbbrs = {
      ls = "eza --icons";
      ll = "eza -lah --icons";
      lt = "eza --tree --icons";
      cat = "bat --style=plain";
      less = "moor";
      more = "moor";
      omp = "omp-safe";
    };
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
    enable = true;
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
    extensions = [
      "nix"
      "toml"
      "go"
    ];
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
          models = [
            {
              name = "glm-5.2:cloud";
              max_input_tokens = 1000000;
            }
          ];
        }
      ];
    };
  };
}
