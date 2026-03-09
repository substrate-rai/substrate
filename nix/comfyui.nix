{ config, pkgs, ... }:

let
  comfyuiDir = "/home/operator/comfyui";
  comfyuiVenv = "${comfyuiDir}/venv/bin/python";
  # LD_LIBRARY_PATH needed for CUDA + C++ runtime on NixOS
  ldLibPath = "/run/opengl-driver/lib:/nix/store/ihpdbhy4rfxaixiamyb588zfc3vj19al-gcc-15.2.0-lib/lib:/nix/store/m028f6iw72di3mqah6zmfpjx91973bk0-cuda-merged-12.4/lib:/nix/store/drxbq03f66krz302bp077bqf0damsayv-zlib-1.3.1/lib:/nix/store/rla54w2i158xf5i5fla3mwh5760x3pgn-libglvnd-1.7.0/lib";
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
