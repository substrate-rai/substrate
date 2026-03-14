"""Blender export template — export scene to glTF/GLB/OBJ/STL/FBX.

Usage (called by blender-ctl.sh, not directly):
  blender --background file.blend --python export_scene.py -- [options]

Options:
  --format gltf|glb|obj|stl|fbx  Export format (default: glb)
  --output PATH                   Output file path
"""
import bpy
import sys
import os

def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    args = {
        "format": "glb",
        "output": None,
    }
    i = 0
    while i < len(argv):
        if argv[i] == "--format" and i + 1 < len(argv):
            args["format"] = argv[i + 1].lower()
            i += 2
        elif argv[i] == "--output" and i + 1 < len(argv):
            args["output"] = argv[i + 1]
            i += 2
        else:
            i += 1
    return args

def main():
    args = parse_args()
    fmt = args["format"]

    if args["output"] is None:
        print("Error: --output is required")
        sys.exit(1)

    output = args["output"]
    os.makedirs(os.path.dirname(os.path.abspath(output)), exist_ok=True)

    if fmt in ("gltf", "glb"):
        bpy.ops.export_scene.gltf(
            filepath=output,
            export_format="GLB" if fmt == "glb" else "GLTF_SEPARATE",
        )
    elif fmt == "obj":
        bpy.ops.wm.obj_export(filepath=output)
    elif fmt == "stl":
        bpy.ops.wm.stl_export(filepath=output)
    elif fmt == "fbx":
        bpy.ops.export_scene.fbx(filepath=output)
    else:
        print(f"Error: unsupported format '{fmt}'")
        print("Supported: gltf, glb, obj, stl, fbx")
        sys.exit(1)

    print(f"Exported: {output} (format={fmt})")

if __name__ == "__main__":
    main()
