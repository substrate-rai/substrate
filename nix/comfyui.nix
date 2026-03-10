{ config, pkgs, ... }:

let
  comfyuiDir = "/home/operator/comfyui";
  comfyuiVenv = "${comfyuiDir}/venv/bin/python";
  # LD_LIBRARY_PATH needed for CUDA + C++ runtime on NixOS
  # Uses dynamic paths via pkgs to survive nixpkgs updates
  ldLibPath = pkgs.lib.makeLibraryPath [
    pkgs.stdenv.cc.cc.lib
    pkgs.cudaPackages.cuda_cudart
    pkgs.cudaPackages.cuda_nvrtc
    pkgs.zlib
    pkgs.libglvnd
    config.hardware.nvidia.package
  ] + ":/run/opengl-driver/lib";
in {
  # ComfyUI — on-demand image generation server on RTX 4060 (8GB VRAM).
  #
  # Model stack: Anime Screenshot Merge NoobAI v4.0 + 90s Retro + JoJo LoRAs
  #
  # Not started automatically (no WantedBy). Start manually when needed:
  #   sudo systemctl start comfyui
  #
  # Listens on 127.0.0.1:8188 (localhost only).
  # Uses the venv Python at /home/operator/comfyui/venv/bin/python.
  #
  # To generate agent portraits after starting:
  #   bash scripts/ml/generate-agent-portraits.sh
  #
  # To generate a single image:
  #   python3 scripts/ml/generate-image.py "prompt" --output filename.png

  systemd.services.comfyui = {
    description = "ComfyUI — Stable Diffusion image generation server";
    after = [ "network.target" ];
    # No wantedBy — started on demand, not at boot.
    # ComfyUI and Ollama compete for the same 8GB of VRAM,
    # so only one should be loaded at a time.

    serviceConfig = {
      Type = "simple";
      User = "operator";
      WorkingDirectory = comfyuiDir;
      ExecStart = "${comfyuiVenv} ${comfyuiDir}/main.py --listen 127.0.0.1 --port 8188 --disable-auto-launch --force-fp16 --fp16-vae --dont-upcast-attention --preview-method taesd";
      Restart = "on-failure";
      RestartSec = 5;

      # CUDA/OpenGL library paths for NixOS
      Environment = "LD_LIBRARY_PATH=${ldLibPath}";
    };

    path = with pkgs; [
      config.boot.kernelPackages.nvidiaPackages.stable.bin
    ];
  };
}
