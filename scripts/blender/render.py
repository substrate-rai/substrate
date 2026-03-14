"""Blender render template — render .blend file to PNG with Cycles or Eevee.

Usage (called by blender-ctl.sh, not directly):
  blender --background file.blend --python render.py -- [options]

Options:
  --engine cycles|eevee   Render engine (default: eevee)
  --gpu                   Use GPU compute (CUDA)
  --samples N             Render samples (default: 128)
  --resolution WxH        Output resolution (default: 1920x1080)
  --output PATH           Output file path (default: /tmp/render.png)
"""
import bpy
import sys

def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    args = {
        "engine": "eevee",
        "gpu": False,
        "samples": 128,
        "resolution": "1920x1080",
        "output": "/tmp/render.png",
    }
    i = 0
    while i < len(argv):
        if argv[i] == "--engine" and i + 1 < len(argv):
            args["engine"] = argv[i + 1].lower()
            i += 2
        elif argv[i] == "--gpu":
            args["gpu"] = True
            i += 1
        elif argv[i] == "--samples" and i + 1 < len(argv):
            args["samples"] = int(argv[i + 1])
            i += 2
        elif argv[i] == "--resolution" and i + 1 < len(argv):
            args["resolution"] = argv[i + 1]
            i += 2
        elif argv[i] == "--output" and i + 1 < len(argv):
            args["output"] = argv[i + 1]
            i += 2
        else:
            i += 1
    return args

def main():
    args = parse_args()
    scene = bpy.context.scene

    # Set render engine
    if args["engine"] == "cycles":
        scene.render.engine = "CYCLES"
        scene.cycles.samples = args["samples"]
        if args["gpu"]:
            scene.cycles.device = "GPU"
            prefs = bpy.context.preferences.addons["cycles"].preferences
            prefs.compute_device_type = "CUDA"
            prefs.get_devices()
            for device in prefs.devices:
                device.use = True
    else:
        scene.render.engine = "BLENDER_EEVEE_NEXT"
        scene.eevee.taa_render_samples = args["samples"]

    # Set resolution
    w, h = args["resolution"].split("x")
    scene.render.resolution_x = int(w)
    scene.render.resolution_y = int(h)
    scene.render.resolution_percentage = 100

    # Set output
    scene.render.filepath = args["output"]
    scene.render.image_settings.file_format = "PNG"

    # Render
    bpy.ops.render.render(write_still=True)
    print(f"Rendered: {args['output']} ({args['resolution']}, {args['engine']}, {args['samples']} samples)")

if __name__ == "__main__":
    main()
