"""Blender mycopunk generator — procedural bioluminescent objects.

Usage (called by blender-ctl.sh, not directly):
  blender --background --python mycopunk.py -- [options]

Options:
  --type mushroom|spore-cluster|bioluminescent-tree|forest-floor
  --color HEXCOLOR     Emission color (default: #00ffaa)
  --emission N         Emission strength (default: 3.0)
  --output PATH        Save .blend file (default: /tmp/mycopunk.blend)
  --render PATH        Also render to PNG (optional)
  --engine cycles|eevee  Render engine (default: eevee)
  --samples N          Render samples (default: 64)
  --resolution WxH     Render resolution (default: 1920x1080)
"""
import bpy
import sys
import math
import random

def hex_to_rgb(hex_color):
    hex_color = hex_color.lstrip("#")
    r = int(hex_color[0:2], 16) / 255.0
    g = int(hex_color[2:4], 16) / 255.0
    b = int(hex_color[4:6], 16) / 255.0
    return (r, g, b, 1.0)

def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    args = {
        "type": "mushroom",
        "color": "#00ffaa",
        "emission": 3.0,
        "output": "/tmp/mycopunk.blend",
        "render": None,
        "engine": "eevee",
        "samples": 64,
        "resolution": "1920x1080",
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
        elif argv[i] == "--render" and i + 1 < len(argv):
            args["render"] = argv[i + 1]
            i += 2
        elif argv[i] == "--engine" and i + 1 < len(argv):
            args["engine"] = argv[i + 1].lower()
            i += 2
        elif argv[i] == "--samples" and i + 1 < len(argv):
            args["samples"] = int(argv[i + 1])
            i += 2
        elif argv[i] == "--resolution" and i + 1 < len(argv):
            args["resolution"] = argv[i + 1]
            i += 2
        else:
            i += 1
    return args

def make_emission_mat(name, color_hex, strength):
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

def make_dark_mat(name):
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    nodes.clear()
    output = nodes.new("ShaderNodeOutputMaterial")
    bsdf = nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Base Color"].default_value = (0.02, 0.02, 0.03, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.9
    links.new(bsdf.outputs["BSDF"], output.inputs["Surface"])
    return mat

def create_mushroom(color, emission_strength):
    """Displaced sphere cap + cylinder stem with emission."""
    # Stem
    bpy.ops.mesh.primitive_cylinder_add(radius=0.15, depth=1.2, location=(0, 0, 0.6))
    stem = bpy.context.active_object
    stem.name = "Stem"
    stem_mat = make_dark_mat("stem_dark")
    stem.data.materials.append(stem_mat)

    # Cap — flattened sphere with subdivision for organic look
    bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=16, radius=0.6, location=(0, 0, 1.2))
    cap = bpy.context.active_object
    cap.name = "Cap"
    cap.scale[2] = 0.4  # Flatten
    bpy.ops.object.modifier_add(type="SUBSURF")
    cap.modifiers["Subdivision"].levels = 2

    # Displace for organic shape
    bpy.ops.object.modifier_add(type="DISPLACE")
    tex = bpy.data.textures.new("cap_displace", type="CLOUDS")
    tex.noise_scale = 0.5
    cap.modifiers["Displace"].texture = tex
    cap.modifiers["Displace"].strength = 0.08

    cap_mat = make_emission_mat("cap_glow", color, emission_strength)
    cap.data.materials.append(cap_mat)

    # Gill rings under cap — emission accent
    bpy.ops.mesh.primitive_torus_add(
        major_radius=0.4, minor_radius=0.03,
        location=(0, 0, 1.05)
    )
    gills = bpy.context.active_object
    gills.name = "Gills"
    gill_mat = make_emission_mat("gill_glow", color, emission_strength * 0.5)
    gills.data.materials.append(gill_mat)

    return [stem, cap, gills]

def create_spore_cluster(color, emission_strength):
    """Cluster of small glowing spheres."""
    objects = []
    random.seed(42)
    for i in range(20):
        x = random.uniform(-0.8, 0.8)
        y = random.uniform(-0.8, 0.8)
        z = random.uniform(0, 1.5)
        r = random.uniform(0.03, 0.12)
        bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=8, radius=r, location=(x, y, z))
        spore = bpy.context.active_object
        spore.name = f"Spore_{i:03d}"
        strength = emission_strength * random.uniform(0.5, 1.5)
        mat = make_emission_mat(f"spore_glow_{i}", color, strength)
        spore.data.materials.append(mat)
        objects.append(spore)
    return objects

def create_bioluminescent_tree(color, emission_strength):
    """Branching cylinders with emission tips."""
    objects = []
    random.seed(42)

    # Trunk
    bpy.ops.mesh.primitive_cylinder_add(radius=0.12, depth=2.0, location=(0, 0, 1.0))
    trunk = bpy.context.active_object
    trunk.name = "Trunk"
    trunk_mat = make_dark_mat("trunk_dark")
    trunk.data.materials.append(trunk_mat)
    objects.append(trunk)

    # Branches
    for i in range(6):
        angle = (i / 6) * 2 * math.pi + random.uniform(-0.3, 0.3)
        height = 1.0 + random.uniform(0.2, 1.2)
        length = random.uniform(0.4, 0.8)
        bpy.ops.mesh.primitive_cylinder_add(
            radius=0.04, depth=length,
            location=(math.cos(angle) * 0.3, math.sin(angle) * 0.3, height)
        )
        branch = bpy.context.active_object
        branch.name = f"Branch_{i}"
        branch.rotation_euler = (
            random.uniform(-0.5, 0.5),
            random.uniform(-0.5, 0.5),
            angle
        )
        branch_mat = make_dark_mat(f"branch_dark_{i}")
        branch.data.materials.append(branch_mat)
        objects.append(branch)

        # Glowing tip
        tip_x = math.cos(angle) * (0.3 + length * 0.4)
        tip_y = math.sin(angle) * (0.3 + length * 0.4)
        bpy.ops.mesh.primitive_uv_sphere_add(
            segments=16, ring_count=8, radius=0.06,
            location=(tip_x, tip_y, height + 0.1)
        )
        tip = bpy.context.active_object
        tip.name = f"Tip_{i}"
        tip_mat = make_emission_mat(f"tip_glow_{i}", color, emission_strength)
        tip.data.materials.append(tip_mat)
        objects.append(tip)

    return objects

def create_forest_floor(color, emission_strength):
    """Ground plane with scattered glowing elements."""
    objects = []
    random.seed(42)

    # Ground plane
    bpy.ops.mesh.primitive_plane_add(size=6, location=(0, 0, 0))
    ground = bpy.context.active_object
    ground.name = "Ground"
    bpy.ops.object.modifier_add(type="SUBSURF")
    ground.modifiers["Subdivision"].levels = 3
    bpy.ops.object.modifier_add(type="DISPLACE")
    tex = bpy.data.textures.new("ground_displace", type="MUSGRAVE")
    ground.modifiers["Displace"].texture = tex
    ground.modifiers["Displace"].strength = 0.15
    ground_mat = make_dark_mat("ground_dark")
    ground.data.materials.append(ground_mat)
    objects.append(ground)

    # Scattered glowing elements
    for i in range(30):
        x = random.uniform(-2.5, 2.5)
        y = random.uniform(-2.5, 2.5)
        z = random.uniform(0.01, 0.08)
        element_type = random.choice(["sphere", "cone"])
        if element_type == "sphere":
            r = random.uniform(0.02, 0.06)
            bpy.ops.mesh.primitive_uv_sphere_add(segments=8, ring_count=4, radius=r, location=(x, y, z))
        else:
            bpy.ops.mesh.primitive_cone_add(radius1=0.04, depth=0.1, location=(x, y, z + 0.05))
        elem = bpy.context.active_object
        elem.name = f"Glow_{i:03d}"
        strength = emission_strength * random.uniform(0.3, 1.2)
        mat = make_emission_mat(f"floor_glow_{i}", color, strength)
        elem.data.materials.append(mat)
        objects.append(elem)

    return objects

def setup_scene(args):
    """Set up camera, world, and render settings."""
    scene = bpy.context.scene

    # Dark world
    world = bpy.data.worlds.get("World") or bpy.data.worlds.new("World")
    scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    if bg:
        bg.inputs["Color"].default_value = (0.01, 0.01, 0.015, 1.0)
        bg.inputs["Strength"].default_value = 1.0

    # Camera
    bpy.ops.object.camera_add(location=(3, -3, 2.5))
    cam = bpy.context.active_object
    cam.rotation_euler = (1.1, 0, 0.8)
    scene.camera = cam

    # Render settings
    if args["engine"] == "cycles":
        scene.render.engine = "CYCLES"
        scene.cycles.samples = args["samples"]
        scene.cycles.device = "GPU"
        prefs = bpy.context.preferences.addons["cycles"].preferences
        prefs.compute_device_type = "CUDA"
        prefs.get_devices()
        for device in prefs.devices:
            device.use = True
    else:
        scene.render.engine = "BLENDER_EEVEE_NEXT"
        scene.eevee.taa_render_samples = args["samples"]

    w, h = args["resolution"].split("x")
    scene.render.resolution_x = int(w)
    scene.render.resolution_y = int(h)
    scene.render.resolution_percentage = 100

def main():
    args = parse_args()

    # Clear default scene
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()

    # Create the requested object
    creators = {
        "mushroom": create_mushroom,
        "spore-cluster": create_spore_cluster,
        "bioluminescent-tree": create_bioluminescent_tree,
        "forest-floor": create_forest_floor,
    }

    creator = creators.get(args["type"])
    if creator is None:
        print(f"Error: unknown mycopunk type '{args['type']}'")
        print(f"Available: {', '.join(creators.keys())}")
        sys.exit(1)

    objects = creator(args["color"], args["emission"])
    setup_scene(args)

    # Save .blend
    bpy.ops.wm.save_as_mainfile(filepath=args["output"])
    print(f"Created: {args['output']} (mycopunk {args['type']}, color={args['color']})")

    # Optionally render
    if args["render"]:
        scene = bpy.context.scene
        scene.render.filepath = args["render"]
        scene.render.image_settings.file_format = "PNG"
        bpy.ops.render.render(write_still=True)
        print(f"Rendered: {args['render']}")

if __name__ == "__main__":
    main()
