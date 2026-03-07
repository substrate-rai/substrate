{
  description = "Substrate — sovereign AI workstation";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
  let
    system = "x86_64-linux";
    pkgs = import nixpkgs {
      inherit system;
      config.allowUnfree = true;
    };
  in {
    nixosConfigurations.substrate = nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [
        ./nix/hardware-configuration.nix
        ./nix/configuration.nix
      ];
    };

    devShells.${system} = {
      default = pkgs.mkShell {
        packages = [
          (pkgs.python3.withPackages (ps: [ ps.requests ]))
        ];
      };

      # ML toolkit — GPU-accelerated image/audio/speech
      ml = pkgs.mkShell {
        packages = [
          (pkgs.python312.withPackages (ps: with ps; [
            torchWithCuda
            torchvision
            torchaudio
            diffusers
            transformers
            accelerate
            safetensors
            pillow
            soundfile
            scipy
            faster-whisper
            requests
          ]))
        ];
      };
    };
  };
}
