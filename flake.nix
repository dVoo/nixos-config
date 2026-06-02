{
  description = "NixOS multi-machine config: pc, hp15, xps — Hyprland, systemd-boot, BTRFS & LUKS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    hyprland.url = "github:hyprwm/Hyprland";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    agenix.url = "github:ryantm/agenix";
    agenix.inputs.nixpkgs.follows = "nixpkgs";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    nix-cachyos-kernel.url = "github:xddxdd/nix-cachyos-kernel/release";
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      agenix,
      hyprland,
      disko,
      nixos-hardware,
      ...
    }@inputs:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };

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
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.users.daniel.imports = [
                ./home.nix
                agenix.homeManagerModules.default
              ];
              home-manager.extraSpecialArgs = { inherit inputs; };
            }
          ];
        };

    in
    {
      nixosConfigurations = {
        pc = mkSystem ./hosts/pc/configuration.nix;
        hp15 = mkSystem ./hosts/hp15/configuration.nix;
        xps = mkSystem ./hosts/xps/configuration.nix;
      };
    };
}
