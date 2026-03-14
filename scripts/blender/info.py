"""Blender scene info template — inspect .blend file contents.

Usage (called by blender-ctl.sh, not directly):
  blender --background file.blend --python info.py
"""
import bpy
import sys

def main():
    scene = bpy.context.scene
    print(f"File: {bpy.data.filepath or '(unsaved)'}")
    print(f"Blender: {bpy.app.version_string}")
    print(f"Scene: {scene.name}")
    print(f"Frame range: {scene.frame_start}-{scene.frame_end}")
    print(f"Render engine: {scene.render.engine}")
    print(f"Resolution: {scene.render.resolution_x}x{scene.render.resolution_y}")
    print()

    # Objects
    objects = list(bpy.data.objects)
    print(f"Objects: {len(objects)}")
    for obj in objects:
        info = f"  {obj.name} [{obj.type}]"
        if obj.type == "MESH":
            mesh = obj.data
            info += f" — {len(mesh.vertices)} verts, {len(mesh.polygons)} faces"
            if mesh.materials:
                mat_names = [m.name for m in mesh.materials if m]
                info += f", materials: [{', '.join(mat_names)}]"
        elif obj.type == "CAMERA":
            info += f" — {obj.data.type.lower()}"
        elif obj.type == "LIGHT":
            info += f" — {obj.data.type.lower()}, {obj.data.energy}W"
        print(info)
    print()

    # Materials
    materials = list(bpy.data.materials)
    print(f"Materials: {len(materials)}")
    for mat in materials:
        node_info = ""
        if mat.use_nodes:
            node_types = [n.type for n in mat.node_tree.nodes]
            node_info = f" — nodes: {', '.join(node_types)}"
        print(f"  {mat.name}{node_info}")
    print()

    # Collections
    collections = list(bpy.data.collections)
    if collections:
        print(f"Collections: {len(collections)}")
        for col in collections:
            print(f"  {col.name} ({len(col.objects)} objects)")

if __name__ == "__main__":
    main()
