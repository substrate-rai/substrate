"""Blender primitive creation template — create objects with emission materials.

Usage (called by blender-ctl.sh, not directly):
  blender --background --python create_primitive.py -- [options]

Options:
  --type cube|sphere|cylinder|torus|monkey  Primitive type (default: cube)
  --color HEXCOLOR                          Emission color (default: #00ffaa)
  --emission N                              Emission strength (default: 2.0)
  --output PATH                             Save .blend file (default: /tmp/primitive.blend)
"""
import bpy
import sys

def hex_to_rgb(hex_color):
    hex_color = hex_color.lstrip("#")
    r = int(hex_color[0:2], 16) / 255.0
    g = int(hex_color[2:4], 16) / 255.0
    b = int(hex_color[4:6], 16) / 255.0
    return (r, g, b, 1.0)

def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    args = {
        "type": "cube",
        "color": "#00ffaa",
        "emission": 2.0,
        "output": "/tmp/primitive.blend",
    }
    i = 0
    while i < len(argv):
        if argv[i] == "--type" and i + 1 < len(argv):
            args["type"] = argv[i + 1].lower()
            i += 2
        elif argv[i] == "--color" and i + 1 < len(argv):
            args["color"] = argv[i + 1]
            i += 2
        elif argv[i] == "--emission" and i + 1 < len(argv):
            args["emission"] = float(argv[i + 1])
            i += 2
        elif argv[i] == "--output" and i + 1 < len(argv):
            args["output"] = argv[i + 1]
            i += 2
        else:
            i += 1
    return args

def create_emission_material(name, color_hex, strength):
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    nodes.clear()

    output = nodes.new("ShaderNodeOutputMaterial")
    emission = nodes.new("ShaderNodeEmission")
    emission.inputs["Color"].default_value = hex_to_rgb(color_hex)
    emission.inputs["Strength"].default_value = strength
    links.new(emission.outputs["Emission"], output.inputs["Surface"])
    return mat

def main():
    args = parse_args()

    # Clear default scene
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()

    # Create primitive
    creators = {
        "cube": bpy.ops.mesh.primitive_cube_add,
        "sphere": lambda: bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=16),
        "cylinder": bpy.ops.mesh.primitive_cylinder_add,
        "torus": bpy.ops.mesh.primitive_torus_add,
        "monkey": bpy.ops.mesh.primitive_monkey_add,
    }

    creator = creators.get(args["type"])
    if creator is None:
        print(f"Error: unknown primitive type '{args['type']}'")
        print(f"Available: {', '.join(creators.keys())}")
        sys.exit(1)

    creator()
    obj = bpy.context.active_object
    obj.name = args["type"].capitalize()

    # Apply emission material
    mat = create_emission_material(f"{args['type']}_emission", args["color"], args["emission"])
    obj.data.materials.append(mat)

    # Add camera and light for completeness
    bpy.ops.object.camera_add(location=(3, -3, 2))
    cam = bpy.context.active_object
    cam.rotation_euler = (1.1, 0, 0.8)
    bpy.context.scene.camera = cam

    # Dark world background
    world = bpy.data.worlds.get("World") or bpy.data.worlds.new("World")
    bpy.context.scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    if bg:
        bg.inputs["Color"].default_value = (0.04, 0.04, 0.06, 1.0)  # #0a0a0f
        bg.inputs["Strength"].default_value = 1.0

    # Save
    bpy.ops.wm.save_as_mainfile(filepath=args["output"])
    print(f"Created: {args['output']} ({args['type']}, color={args['color']}, emission={args['emission']})")

if __name__ == "__main__":
    main()
