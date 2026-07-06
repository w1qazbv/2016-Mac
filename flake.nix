{
  description = "NixOS configuration for 2016 12-inch MacBook";

  inputs = {
    # Match this to your preferred NixOS stable channel
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.11";
  };

  outputs = { self, nixpkgs, ... }@inputs: {
    nixosConfigurations = {
      # Change "macbook" to whatever hostname you want
      macbook = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./configuration.nix
        ];
      };
    };
  };
}