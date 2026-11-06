{
  config,
  lib,
  pkgs,
  inputs,
  systemAgeSecrets,
  ...
}:

let
  # API keys are delivered through two mechanisms on purpose:
  #
  #  1. home.sessionVariables (further down) exports them for interactive
  #     shells. This is what tools launched from a terminal see, and it is
  #     mandatory for avante.nvim, which reads the *variable* named by
  #     `api_key_name` rather than a file or a wrapper.
  #
  #  2. The wrappers below export the same values for anything started from
  #     the Noctalia launcher or from a systemd user unit. Those do NOT source
  #     hm-session-vars.sh — Home Manager writes it into profile.d only — which
  #     is why an app launched from the launcher previously had no API keys at
  #     all.
  withApiKeys =
    name: pkg:
    pkgs.writeShellScriptBin name ''
      set -euo pipefail
      export OLLAMA_API_KEY="$(cat ${systemAgeSecrets.ollama-api-key.path})"
      export OPENROUTER_API_KEY="$(cat ${systemAgeSecrets.openrouter-api-key.path})"
      export DEEPSEEK_API_KEY="$(cat ${systemAgeSecrets.deepseek-api-key.path})"
      export OPENCODE_API_KEY="$(cat ${systemAgeSecrets.opencode-api-key.path})"
      exec ${pkg}/bin/${name} "$@"
    '';
in

{
  # Secrets.
  #
  # The API keys, the kubeconfig and the rest are decrypted by the *system*
  # agenix module (modules/common.nix) using the machines' SSH host keys. That
  # module runs during system activation, before any user session exists, and —
  # unlike home-manager's agenix module — it does not depend on daniel's
  # personal ~/.ssh key being present, which is what used to make a fresh
  # install fail at home-manager activation.
  #
  # All that is left to do here is the wiring into the home directory: kubectl,
  # k9s and editor plugins all expect ~/.kube/config. This has to be a symlink
  # created by an activation script rather than home.file.​.source, because
  # home-manager's file builder would copy the secret into the world-readable
  # Nix store.
  home.activation.linkKubeconfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    install -d -m 700 "$HOME/.kube"
    ln -sfn ${systemAgeSecrets.kubeconfig.path} "$HOME/.kube/config"
  '';

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

  # nix.gc in modules/common.nix only collects *system* profiles. Home Manager
  # generations live in the per-user profile directory, so they were never
  # collected and accumulated indefinitely. Same 30-day retention, run as the
  # user (which is what makes the per-user profiles visible to the collector).
  systemd.user.services.nix-gc-user = {
    Unit.Description = "Collect old user-profile generations";
    Service = {
      Type = "oneshot";
      ExecStart = "${pkgs.nix}/bin/nix-collect-garbage --delete-older-than 30d";
    };
  };
  systemd.user.timers.nix-gc-user = {
    Unit.Description = "Weekly user-profile garbage collection";
    Timer = {
      OnCalendar = "weekly";
      Persistent = true;
    };
    Install.WantedBy = [ "timers.target" ];
  };

  home.sessionVariables = {
    OPENCODE_EXPERIMENTAL_BACKGROUND_SUBAGENTS = true;
    OLLAMA_API_KEY = "$(cat ${systemAgeSecrets.ollama-api-key.path})";
    OPENROUTER_API_KEY = "$(cat ${systemAgeSecrets.openrouter-api-key.path})";
    DEEPSEEK_API_KEY = "$(cat ${systemAgeSecrets.deepseek-api-key.path})";
    PAGER = "moor";
  };

  home.packages = with pkgs; [
    font-awesome
    inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default
    fd
    jq
    ripgrep
    # gcr and grc deliberately not installed: gcr is a deprecated stack, and
    # grc only works with shell integration that fish never gets from this
    # configuration.
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
    translate-shell
    # opencode is wrapped so its API keys are present when it is started from
    # the Noctalia launcher or a user unit instead of a terminal. (aichat is
    # wrapped the same way, but through programs.aichat.package below, because
    # that module installs the package itself and two bin/aichat owners make
    # buildEnv fail.)
    (withApiKeys "opencode" opencode)
    glow
    tor-browser
    typst
    inkscape
    ferdium

    #programming
    go
    gcc
    gnumake
    binutils
    pkg-config
    # NOTE: pkgs.opencode is deliberately absent here: the key-injecting
    # wrapper added above already installs a bin/opencode that execs it, and
    # having both in home.packages makes buildEnv fail with
    # "two given paths contain a conflicting subpath" for bin/opencode.
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
    pi-coding-agent
  ];

  # ProtonVPN port forward
  home.file.".local/bin/protonvpn-forward" = {
    text = ''
      #!/usr/bin/env bash
      while true ; do date ; natpmpc -a 1 0 udp 60 -g 10.2.0.1 && natpmpc -a 1 0 tcp 60 -g 10.2.0.1 || { echo -e "ERROR with natpmpc command \a" ; break ; } ; sleep 45 ; done
    '';
    executable = true;
  };

  home.file.".local/bin/pi-safe" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      set -euo pipefail

      PROJECT_DIR="$(pwd)"
      mkdir -p "$HOME/.pi"

      # Clipboard: the --tmpfs over $XDG_RUNTIME_DIR below leaves the sandbox
      # without the Wayland socket, so pi's wl-copy fallback cannot work and
      # (because WAYLAND_DISPLAY is still set) it does not try OSC 52 either.
      # This flag only flips pi to the OSC 52 path, which writes the copy over
      # the pty and lets kitty put it on the system clipboard — no compositor
      # socket inside the sandbox. Write-only: pi's own paste (wl-paste) stays
      # unavailable, pasting into the terminal still works via kitty's own
      # Ctrl+Shift+V. Copies survive pi exiting because kitty owns them.
      exec bwrap \
        --ro-bind /nix /nix \
        --ro-bind /etc /etc \
        --ro-bind /usr /usr \
        --ro-bind-try /lib /lib \
        --ro-bind-try /lib64 /lib64 \
        --ro-bind-try /run/current-system /run/current-system \
        --ro-bind-try /home/daniel/.config/git/config /home/daniel/.config/git/config \
        --ro-bind-try /home/daniel/.config/jj /home/daniel/.config/jj \
        --proc /proc \
        --dev /dev \
        --tmpfs /tmp \
        --tmpfs "/run/user/$(id -u)" \
        --bind "$HOME/.pi" "$HOME/.pi" \
        --bind "$PROJECT_DIR" "$PROJECT_DIR" \
        --bind-try "$PROJECT_DIR/.git" "$PROJECT_DIR/.git" \
        --unshare-pid --unshare-ipc --unshare-uts \
        --share-net \
        --new-session \
        --die-with-parent \
        --chdir "$PROJECT_DIR" \
        --setenv HOME "$HOME" \
        --setenv XDG_RUNTIME_DIR "/run/user/$(id -u)" \
        --setenv PI_CLIPBOARD_OSC52 1 \
        -- pi "$@"
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
      # background_blur was removed: it is a KWin-specific hint that no Wayland
      # compositor reads. (niri 26.04 has real background blur, but that is a
      # niri `background-effect` window rule — deliberately left off, since blur
      # costs GPU time and power.)
      enable_audio_bell = false;
    };
  };
  programs.fish = {
    enable = true;
    shellAliases = {
      # The flake evaluates purely (verified with `nix flake check` and a
      # plain `nix build` of the toplevel), so --impure was unnecessary.
      rebuild = "sudo nixos-rebuild switch --flake ~/nixos-config";
      boot = "sudo nixos-rebuild boot --flake ~/nixos-config";
      # `try`, not `test`: Home Manager renders fish aliases as functions
      # (`function <name> --wraps ...`), and fish refuses to define a function
      # named after a reserved word, so an alias called `test` made every
      # startup print
      #   function: test: cannot use reserved keyword as function name
      # and the alias was never created. The same applies to any other keyword
      # (if/for/while/begin/end/function/...); none of the other alias names
      # here collide. scripts/verify-after-switch.sh sources the generated
      # config.fish with fish so this class of error is caught in future.
      try = "sudo nixos-rebuild test --flake ~/nixos-config";
      build = "nixos-rebuild build --flake ~/nixos-config";
      check = "nix flake check --no-build ~/nixos-config";
      # `nix flake update` treats positional arguments as *input names* and
      # always operates on the flake in the cwd, so the flake must be
      # selected with --flake. The old form (`nix flake update <path>`) could
      # never have worked.
      update = "nix flake update --flake ~/nixos-config";
      # System-wide GC on demand. nix.gc (modules/common.nix, 30d) and the
      # weekly per-user timer in this file already handle retention, so this is
      # only for "free space now" — and it needs root, because the plain
      # user-level `nix-collect-garbage -d` can only prune daniel's own
      # profiles, not the system ones or the store paths they reference.
      gc = "sudo nix-collect-garbage --delete-older-than 30d";
    };
    # Modern replacements for ls, cat, less/more; omp alias to the bwrap
    # sandbox wrapper so an unqualified `omp` runs the user-managed binary
    # under bwrap. The raw binary at ~/.local/bin/omp stays free for explicit
    # invocations like `~/.local/bin/omp update`.
    shellAbbrs = {
      ls = "eza --icons=always";
      ll = "eza -lah --icons=always";
      lt = "eza --tree --icons=always";
      cat = "bat --style=plain";
      less = "moor";
      more = "moor";
      pi = "pi-safe";
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
  #
  # fzf
  programs.fzf = {
    enable = true;
    enableFishIntegration = true;
  };

  # Helix was removed: LazyVim is the editor in use (Zed is kept as the GUI
  # alternative). Dropping it also removes the reason for the separate
  # `defaultEditor = false` flag that used to disambiguate the two.

  # Git
  programs.git = {
    enable = true;
    # Single settings attrset: the previous split (`settings = {...};` plus
    # `settings.user = {...};`) relied on Nix merging dotted paths into the
    # literal and was easy to misread as an error.
    settings = {
      init.defaultBranch = "main";
      pull.rebase = false;
      user = {
        name = "Daniel Vollrath";
        email = "daniel@danielvollrath.de";
      };
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
  # The individual download/desktop/documents/... paths used to be spelled out
  # here, but they are exactly the module defaults ($HOME/Downloads and so on),
  # so they are omitted.

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
    # The module installs this package into home.packages, so the wrapper has to
    # be supplied here rather than added to home.packages as well — otherwise
    # two paths provide bin/aichat and buildEnv refuses to build.
    package = withApiKeys "aichat" pkgs.aichat;
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
