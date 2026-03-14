"""Blender format conversion template — import A, export B.

Usage (called by blender-ctl.sh, not directly):
  blender --background --python convert.py -- --input FILE --output FILE

Infers formats from file extensions.
Supported: .blend, .obj, .stl, .fbx, .gltf, .glb, .ply
"""
import bpy
import sys
import os

def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    args = {"input": None, "output": None}
    i = 0
    while i < len(argv):
        if argv[i] == "--input" and i + 1 < len(argv):
            args["input"] = argv[i + 1]
            i += 2
        elif argv[i] == "--output" and i + 1 < len(argv):
            args["output"] = argv[i + 1]
            i += 2
        else:
            i += 1
    return args

def import_file(filepath):
    ext = os.path.splitext(filepath)[1].lower()
    if ext == ".blend":
        bpy.ops.wm.open_mainfile(filepath=filepath)
    elif ext == ".obj":
        bpy.ops.wm.obj_import(filepath=filepath)
    elif ext == ".stl":
        bpy.ops.wm.stl_import(filepath=filepath)
    elif ext == ".fbx":
        bpy.ops.import_scene.fbx(filepath=filepath)
    elif ext in (".gltf", ".glb"):
        bpy.ops.import_scene.gltf(filepath=filepath)
    elif ext == ".ply":
        bpy.ops.wm.ply_import(filepath=filepath)
    else:
        print(f"Error: unsupported input format '{ext}'")
        sys.exit(1)

def export_file(filepath):
    ext = os.path.splitext(filepath)[1].lower()
    os.makedirs(os.path.dirname(os.path.abspath(filepath)), exist_ok=True)
    if ext == ".blend":
        bpy.ops.wm.save_as_mainfile(filepath=filepath)
    elif ext == ".obj":
        bpy.ops.wm.obj_export(filepath=filepath)
    elif ext == ".stl":
        bpy.ops.wm.stl_export(filepath=filepath)
    elif ext == ".fbx":
        bpy.ops.export_scene.fbx(filepath=filepath)
    elif ext == ".glb":
        bpy.ops.export_scene.gltf(filepath=filepath, export_format="GLB")
    elif ext == ".gltf":
        bpy.ops.export_scene.gltf(filepath=filepath, export_format="GLTF_SEPARATE")
    elif ext == ".ply":
        bpy.ops.wm.ply_export(filepath=filepath)
    else:
        print(f"Error: unsupported output format '{ext}'")
        sys.exit(1)

def main():
    args = parse_args()
    if not args["input"] or not args["output"]:
        print("Error: --input and --output are required")
        sys.exit(1)

    # Clear default scene
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()

    print(f"Importing: {args['input']}")
    import_file(args["input"])

    print(f"Exporting: {args['output']}")
    export_file(args["output"])

    print(f"Converted: {args['input']} → {args['output']}")

if __name__ == "__main__":
    main()
