{
  config,
  pkgs,
  inputs,
  lib,
  ...
}:

{
  programs.lazyvim = {
    enable = true;
    appName = "nvim";
    pluginSource = "latest";
    installCoreDependencies = true;

    # LazyVim extras matching the previous lazyvim.json
    extras = {
      ai.avante.enable = true;
      coding.mini-surround.enable = true;
      coding.yanky.enable = true;
      lang.nix.enable = true;
      lang.go.enable = true;
      lang.python.enable = true;
    };

    # External binaries needed by plugins
    extraPackages = with pkgs; [
      # avante.nvim runtime deps (web scraping, build features)
      python3
      nodejs
    ];

    # Custom plugin specs — only what differs from LazyVim defaults
    plugins = {
      # Colorscheme: tokyonight-night
      colorscheme = inputs.lazyvim-nix.lib.lazyConfig [
        {
          plugin = "ayu-theme/ayu-vim";
        }
        {
          plugin = "LazyVim/LazyVim";
          opts = {
            colorscheme = "ayu";
          };
        }
      ];

      # avante.nvim with Ollama backend
      avante = inputs.lazyvim-nix.lib.lazyConfig {
        plugin = "yetone/avante.nvim";
        event = "VeryLazy";
        version = false;
        opts = {
          provider = "ollama";
          providers = {
            ollama = {
              endpoint = "https://ollama.com/";
              model = "glm-5.2";
              api_key_name = "OLLAMA_API_KEY";
            };
          };
        };
      };
    };

    # No custom options/keymaps/autocmds — sticking to LazyVim defaults
  };

  # Make nvim the default editor
  programs.neovim.defaultEditor = true;
}
