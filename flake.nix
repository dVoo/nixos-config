{
  description = "NixOS Gaming Setup with Hyprland, systemd-boot, BTRFS & LUKS";

  inputs = {
    # ... (keep your inputs exactly as they are)
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    hyprland.url = "github:hyprwm/Hyprland";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    agenix.url = "github:ryantm/agenix";
    agenix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-unstable,
      home-manager,
      agenix,
      hyprland,
      disko,
      ...
    }@inputs:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };

      # Configure unstable packages
      pkgs-unstable = import nixpkgs-unstable {
        inherit system;
        config.allowUnfree = true;
      };

      # 1. Define a Reusable Function
      # This function accepts a path (hostConfig) and builds a system
      mkSystem =
        hostConfig:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit inputs pkgs-unstable; };
          modules = [
            # Shared Modules
            disko.nixosModules.disko
            #chaotic.nixosModules.default
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
              home-manager.extraSpecialArgs = { inherit inputs pkgs-unstable; };
            }
          ];
        };

    in
    {
      # 2. Call the function for each host
      nixosConfigurations = {

        # Your original PC
        pc = mkSystem ./hosts/pc/configuration.nix;

        # Your new Laptop
        hp15 = mkSystem ./hosts/hp15/configuration.nix;

        # xps
        xps = mkSystem ./hosts/xps/configuration.nix;
      };
    };
}
