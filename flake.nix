{
  description = "Substrate — sovereign AI workstation";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
  };

  outputs = { self, nixpkgs }: {
    nixosConfigurations.substrate = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./nix/hardware-configuration.nix
        ./nix/configuration.nix
      ];
    };
  };
}
