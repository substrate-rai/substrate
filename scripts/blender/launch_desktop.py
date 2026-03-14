"""Launch Blender on the desktop with Substrate Live Server auto-enabled.

Usage:
    DISPLAY=:0 blender --python scripts/blender/launch_desktop.py
    DISPLAY=:0 blender --python scripts/blender/launch_desktop.py -- --scene mycopunk
"""
import bpy
import sys
import os

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))

def setup_viewport():
    """Set viewport to Material Preview with dark theme."""
    for area in bpy.context.screen.areas:
        if area.type == "VIEW_3D":
            for space in area.spaces:
                if space.type == "VIEW_3D":
                    space.shading.type = "MATERIAL"
                    space.shading.use_scene_lights = True
                    space.shading.use_scene_world = True
            break


def setup_dark_world():
    """Set up the dark mycopunk world background."""
    world = bpy.data.worlds.get("World") or bpy.data.worlds.new("World")
    bpy.context.scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    if bg:
        bg.inputs["Color"].default_value = (0.01, 0.01, 0.015, 1.0)
        bg.inputs["Strength"].default_value = 1.0


def setup_eevee():
    """Configure EEVEE for real-time preview."""
    scene = bpy.context.scene
    # Blender 5.x: BLENDER_EEVEE; 4.x: BLENDER_EEVEE_NEXT
    try:
        scene.render.engine = "BLENDER_EEVEE"
    except TypeError:
        scene.render.engine = "BLENDER_EEVEE_NEXT"
    try:
        scene.eevee.taa_render_samples = 64
    except AttributeError:
        pass
    scene.render.resolution_x = 1920
    scene.render.resolution_y = 1080


def load_addon():
    """Register and start the Substrate Live Server addon."""
    # Import and register the addon directly
    sys.path.insert(0, SCRIPT_DIR)
    import substrate_server
    substrate_server.register()
    substrate_server.start_server()
    print("[launch] Substrate Live Server started")


def parse_args():
    """Parse launch arguments."""
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    args = {"scene": None}
    i = 0
    while i < len(argv):
        if argv[i] == "--scene" and i + 1 < len(argv):
            args["scene"] = argv[i + 1]
            i += 2
        else:
            i += 1
    return args


def create_starter_scene():
    """Create a simple mycopunk starter scene — one mushroom + camera."""
    # Clear defaults
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()

    try:
        import mycopunk
        mycopunk.create_mushroom("#00ffaa", 3.0)

        # Camera
        bpy.ops.object.camera_add(location=(3, -3, 2.5))
        cam = bpy.context.active_object
        cam.rotation_euler = (1.1, 0, 0.8)
        bpy.context.scene.camera = cam
        print("[launch] Starter mushroom scene created")
    except ImportError:
        print("[launch] mycopunk.py not found, starting with empty scene")


def main():
    args = parse_args()

    setup_dark_world()
    setup_eevee()

    if args["scene"] == "mycopunk":
        create_starter_scene()

    setup_viewport()
    load_addon()

    print("[launch] Substrate desktop ready — send commands to localhost:9876")


main()
