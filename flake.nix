{
  description = "NixOS multi-machine config: pc, xps, yoga — Hyprland, systemd-boot, BTRFS & LUKS";

  # Substituters are configured through nix.settings (modules/common.nix and
  # hosts/pc/configuration.nix), deliberately not in a flake `nixConfig`
  # block. A `nixConfig` block was tried and reverted: because flake config
  # from the flake itself is untrusted by default, every single nix
  # invocation then printed
  #   warning: ignoring untrusted flake configuration setting 'extra-substituters'
  # twice, and the system-level nix.settings already provides the same caches
  # once the machine is installed.

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # The `hyprland` input was removed. Nothing referenced inputs.hyprland:
    # the compositor is configured through Home Manager's built-in hyprland
    # module and the package comes from nixpkgs. It nevertheless dragged a
    # second nixpkgs plus ~40 nested inputs (aquamarine, hyprtoolkit, xdph,
    # pre-commit-hooks, ...) into the lock file and into every evaluation.
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    agenix.url = "github:ryantm/agenix";
    agenix.inputs.nixpkgs.follows = "nixpkgs";
    nixos-hardware = {
      url = "github:NixOS/nixos-hardware/master";
      # Without this, nixos-hardware pins its own nixpkgs (a
      # releases.nixos.org tarball), instantiating a second full nixpkgs and
      # roughly doubling evaluation work for no benefit.
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-cachyos-kernel.url = "github:xddxdd/nix-cachyos-kernel/release";
    noctalia = {
      url = "github:noctalia-dev/noctalia/cachix";
    };
    zen-browser = {
      url = "github:youwen5/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    lazyvim-nix = {
      url = "github:pfassina/lazyvim-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      agenix,
      disko,
      nixos-hardware,
      noctalia,
      zen-browser,
      lazyvim-nix,
      ...
    }@inputs:
    let
      system = "x86_64-linux";
      # A top-level `pkgs = import nixpkgs { config.allowUnfree = true; }` used
      # to live here but was never referenced (every consumer goes through
      # nixosSystem, which brings its own pkgs). allowUnfree is set once in
      # modules/common.nix.

      # Reusable function to build a NixOS system for each host
      mkSystem =
        hostConfig:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit inputs nixos-hardware; };
          modules = [
            # Shared Modules
            disko.nixosModules.disko
            agenix.nixosModules.default
            home-manager.nixosModules.home-manager

            # The Host-Specific Config (passed as an argument)
            hostConfig

            # Shared Home Manager Config
            ({ config, ... }: {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.users.daniel.imports = [
                ./home.nix
                inputs.noctalia.homeModules.default
                inputs.lazyvim-nix.homeManagerModules.default
              ];
              # agenix.homeManagerModules.default is deliberately absent: every
              # secret is decrypted by the system module (see modules/common.nix)
              # so that nothing depends on daniel's personal SSH key at
              # home-manager activation time.
              home-manager.extraSpecialArgs = {
                inherit inputs;
                systemAgeSecrets = config.age.secrets;
              };
            })
          ];
        };

    in
    {
      nixosConfigurations = {
        pc = mkSystem ./hosts/pc/configuration.nix;
        xps = mkSystem ./hosts/xps/configuration.nix;
        yoga = mkSystem ./hosts/yoga/configuration.nix;
      };
    };
}
