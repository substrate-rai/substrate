{
  description = "Substrate — sovereign AI workstation";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
  };

  outputs = { self, nixpkgs }:
  let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};
  in {
    nixosConfigurations.substrate = nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [
        ./nix/hardware-configuration.nix
        ./nix/configuration.nix
      ];
    };

    devShells.${system}.default = pkgs.mkShell {
      packages = [
        (pkgs.python3.withPackages (ps: [ ps.requests ]))
      ];
    };
  };
}
