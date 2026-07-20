{
  description = "Minimal niri and Quickshell desktop for NixOS and Arch";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ nixpkgs, home-manager, ... }:
  let
    mkHost = { name, module, homeStateVersion, system ? "x86_64-linux", username ? "anton" }:
    nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = { inherit inputs username; hostName = name; };
      modules = [
        module
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.extraSpecialArgs = {
            inherit inputs username homeStateVersion;
            hostName = name;
          };
          home-manager.users.${username} = import ./nixos/modules/home.nix;
        }
      ];
    };
  in
  {
    nixosConfigurations = {
      laptop = mkHost {
        name = "laptop";
        username = "anton";
        homeStateVersion = "26.05";
        module = ./hosts/laptop/nixos/default.nix;
      };
    };
  };
}
