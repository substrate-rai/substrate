"""Substrate Live Server — Blender addon for real-time control via Claude Code.

Runs a TCP socket server inside Blender's GUI on localhost:9876.
Commands arrive as JSON, get queued, and execute in the main thread via bpy.app.timers.

Install: Edit > Preferences > Add-ons > Install from Disk > select this file
  Or: launch with --python scripts/blender/launch_desktop.py (auto-enables)
"""
bl_info = {
    "name": "Substrate Live Server",
    "author": "Substrate AI",
    "version": (1, 0, 0),
    "blender": (4, 0, 0),
    "location": "View3D > Sidebar > Substrate",
    "description": "TCP socket server for live scene control from Claude Code",
    "category": "System",
}

import bpy
import json
import socket
import select
import threading
import queue
import traceback
import sys
import os

# ── Constants ────────────────────────────────────────────────────────────────

HOST = "127.0.0.1"
PORT = 9876
POLL_INTERVAL = 0.1  # seconds

# ── Global State ─────────────────────────────────────────────────────────────

_server_socket = None
_clients = []
_cmd_queue = queue.Queue()
_response_map = {}  # id -> response string
_running = False

# ── Mycopunk Imports ─────────────────────────────────────────────────────────
# Add the blender scripts dir to path so we can import mycopunk

_script_dir = os.path.dirname(os.path.abspath(__file__))
if _script_dir not in sys.path:
    sys.path.insert(0, _script_dir)

def _get_mycopunk():
    """Lazy import mycopunk to avoid issues at addon registration time."""
    try:
        import mycopunk
        return mycopunk
    except ImportError:
        return None

# ── Command Handlers ─────────────────────────────────────────────────────────

def handle_exec(params):
    """Execute arbitrary bpy code."""
    code = params if isinstance(params, str) else params.get("code", "")
    if not code:
        return {"status": "error", "message": "No code provided"}
    try:
        # Provide bpy and mathutils in exec namespace
        ns = {"bpy": bpy, "__builtins__": __builtins__}
        try:
            import mathutils
            ns["mathutils"] = mathutils
        except ImportError:
            pass
        exec(code, ns)
        return {"status": "ok"}
    except Exception as e:
        return {"status": "error", "message": str(e)}


def handle_mushroom(params):
    """Spawn a mycopunk mushroom."""
    mp = _get_mycopunk()
    if not mp:
        return {"status": "error", "message": "mycopunk.py not found in scripts/blender/"}
    color = params.get("color", "#00ffaa")
    emission = params.get("emission", 3.0)
    x = params.get("x", 0)
    y = params.get("y", 0)
    z = params.get("z", 0)

    # Create at origin, then move
    objs = mp.create_mushroom(color, emission)
    for obj in objs:
        obj.location.x += x
        obj.location.y += y
        obj.location.z += z
    names = [o.name for o in objs]
    return {"status": "ok", "objects": names}


def handle_spore_cluster(params):
    """Spawn a spore cluster."""
    mp = _get_mycopunk()
    if not mp:
        return {"status": "error", "message": "mycopunk.py not found"}
    color = params.get("color", "#ff77ff")
    emission = params.get("emission", 3.0)
    x = params.get("x", 0)
    y = params.get("y", 0)
    z = params.get("z", 0)
    objs = mp.create_spore_cluster(color, emission)
    for obj in objs:
        obj.location.x += x
        obj.location.y += y
        obj.location.z += z
    names = [o.name for o in objs]
    return {"status": "ok", "objects": names}


def handle_tree(params):
    """Spawn a bioluminescent tree."""
    mp = _get_mycopunk()
    if not mp:
        return {"status": "error", "message": "mycopunk.py not found"}
    color = params.get("color", "#77aaff")
    emission = params.get("emission", 3.0)
    x = params.get("x", 0)
    y = params.get("y", 0)
    z = params.get("z", 0)
    objs = mp.create_bioluminescent_tree(color, emission)
    for obj in objs:
        obj.location.x += x
        obj.location.y += y
        obj.location.z += z
    names = [o.name for o in objs]
    return {"status": "ok", "objects": names}


def handle_forest_floor(params):
    """Generate full forest floor scene."""
    mp = _get_mycopunk()
    if not mp:
        return {"status": "error", "message": "mycopunk.py not found"}
    color = params.get("color", "#00ffaa")
    emission = params.get("emission", 3.0)
    objs = mp.create_forest_floor(color, emission)
    names = [o.name for o in objs]
    return {"status": "ok", "objects": names}


def handle_clear(params):
    """Clear all objects from the scene."""
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    return {"status": "ok", "message": "Scene cleared"}


def handle_camera(params):
    """Move or create camera."""
    x = params.get("x", 3)
    y = params.get("y", -3)
    z = params.get("z", 2.5)
    rx = params.get("rx", 1.1)
    ry = params.get("ry", 0)
    rz = params.get("rz", 0.8)

    cam = bpy.context.scene.camera
    if cam is None:
        bpy.ops.object.camera_add(location=(x, y, z))
        cam = bpy.context.active_object
        bpy.context.scene.camera = cam
    else:
        cam.location = (x, y, z)
    cam.rotation_euler = (rx, ry, rz)
    return {"status": "ok", "camera": cam.name}


def handle_animate(params):
    """Add keyframe animation to an object."""
    target_name = params.get("target")
    if not target_name:
        return {"status": "error", "message": "No target specified"}

    obj = bpy.data.objects.get(target_name)
    if not obj:
        return {"status": "error", "message": f"Object '{target_name}' not found"}

    prop = params.get("property", "rotation_euler")
    axis = params.get("axis", 2)
    start_val = params.get("start", 0)
    end_val = params.get("end", 6.28)
    start_frame = params.get("start_frame", 1)
    end_frame = params.get("end_frame", params.get("frames", 120))

    scene = bpy.context.scene
    scene.frame_start = min(scene.frame_start, start_frame)
    scene.frame_end = max(scene.frame_end, end_frame)

    # Set start keyframe
    scene.frame_set(start_frame)
    attr = getattr(obj, prop)
    attr[axis] = start_val
    obj.keyframe_insert(data_path=prop, index=axis, frame=start_frame)

    # Set end keyframe
    scene.frame_set(end_frame)
    attr[axis] = end_val
    obj.keyframe_insert(data_path=prop, index=axis, frame=end_frame)

    scene.frame_set(start_frame)
    return {"status": "ok", "target": target_name, "frames": f"{start_frame}-{end_frame}"}


def handle_scene_setup(params):
    """Set up dark world + camera + render settings for mycopunk."""
    mp = _get_mycopunk()
    if not mp:
        return {"status": "error", "message": "mycopunk.py not found"}
    args = {
        "engine": params.get("engine", "eevee"),
        "samples": params.get("samples", 64),
        "resolution": params.get("resolution", "1920x1080"),
    }
    mp.setup_scene(args)
    return {"status": "ok", "message": "Scene configured for mycopunk"}


def handle_status(params):
    """Return scene info."""
    scene = bpy.context.scene
    objects = [{"name": o.name, "type": o.type, "location": list(o.location)} for o in scene.objects]
    return {
        "status": "ok",
        "scene": scene.name,
        "frame": scene.frame_current,
        "frame_range": [scene.frame_start, scene.frame_end],
        "object_count": len(objects),
        "objects": objects,
        "engine": scene.render.engine,
        "camera": scene.camera.name if scene.camera else None,
    }


HANDLERS = {
    "exec": handle_exec,
    "mushroom": handle_mushroom,
    "spore_cluster": handle_spore_cluster,
    "tree": handle_tree,
    "forest_floor": handle_forest_floor,
    "clear": handle_clear,
    "camera": handle_camera,
    "animate": handle_animate,
    "scene_setup": handle_scene_setup,
    "status": handle_status,
}

# ── Socket Server ────────────────────────────────────────────────────────────

def start_server():
    """Start the TCP socket server."""
    global _server_socket, _running

    if _running:
        return False

    _server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    _server_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    _server_socket.setblocking(False)
    _server_socket.bind((HOST, PORT))
    _server_socket.listen(5)
    _running = True

    bpy.app.timers.register(_server_tick, first_interval=POLL_INTERVAL)

    print(f"[substrate] Server listening on {HOST}:{PORT}")
    return True


def stop_server():
    """Stop the TCP socket server."""
    global _server_socket, _running, _clients

    _running = False

    for client in _clients:
        try:
            client.close()
        except Exception:
            pass
    _clients.clear()

    if _server_socket:
        try:
            _server_socket.close()
        except Exception:
            pass
        _server_socket = None

    # Timers auto-unregister when they return None
    print("[substrate] Server stopped")


def _server_tick():
    """Single timer callback: accept connections, read data, execute commands.

    Merged into one timer to avoid race conditions between poll and process.
    Wrapped in a top-level try/except so a crash never silently kills the timer.
    """
    global _server_socket, _clients, _running

    if not _running or not _server_socket:
        return None  # unregister timer

    try:
        # Accept new connections
        try:
            readable, _, _ = select.select([_server_socket], [], [], 0)
            if readable:
                client, addr = _server_socket.accept()
                client.setblocking(False)
                _clients.append(client)
                print(f"[substrate] Client connected from {addr}")
        except Exception:
            pass

        # Read from existing clients
        dead = []
        for client in list(_clients):
            try:
                readable, _, _ = select.select([client], [], [], 0)
                if not readable:
                    continue
                data = client.recv(65536)
                if not data:
                    dead.append(client)
                    continue

                # Parse and execute immediately (we're in main thread)
                try:
                    msg = json.loads(data.decode("utf-8").strip())
                except json.JSONDecodeError as e:
                    _send_response(client, {"status": "error", "message": f"Invalid JSON: {e}"})
                    continue

                cmd_type = msg.get("type", "")
                params = msg.get("params", {})

                # For "exec", code can be top-level
                if cmd_type == "exec" and isinstance(msg.get("code"), str):
                    params = msg.get("code", "")

                handler = HANDLERS.get(cmd_type)
                if handler:
                    try:
                        result = handler(params)
                    except Exception as e:
                        result = {"status": "error", "message": str(e), "traceback": traceback.format_exc()}
                else:
                    result = {"status": "error", "message": f"Unknown command type: {cmd_type}"}

                _send_response(client, result)

            except (ConnectionResetError, BrokenPipeError, OSError):
                dead.append(client)

        for client in dead:
            try:
                client.close()
            except Exception:
                pass
            if client in _clients:
                _clients.remove(client)

    except Exception as e:
        # Never let the timer die silently
        print(f"[substrate] Timer error (recovering): {e}")
        traceback.print_exc()

    return POLL_INTERVAL  # always re-register


def _send_response(client, result):
    """Send JSON response to client, handling errors."""
    try:
        response = json.dumps(result)
        client.sendall(response.encode("utf-8") + b"\n")
    except (BrokenPipeError, ConnectionResetError, OSError):
        try:
            client.close()
        except Exception:
            pass
        if client in _clients:
            _clients.remove(client)


# ── Blender UI Panel ─────────────────────────────────────────────────────────

class SUBSTRATE_PT_ServerPanel(bpy.types.Panel):
    bl_label = "Substrate Live"
    bl_idname = "SUBSTRATE_PT_server"
    bl_space_type = "VIEW_3D"
    bl_region_type = "UI"
    bl_category = "Substrate"

    def draw(self, context):
        layout = self.layout
        if _running:
            layout.label(text=f"Listening on {HOST}:{PORT}", icon="LINKED")
            layout.label(text=f"Clients: {len(_clients)}")
            layout.operator("substrate.stop_server", text="Stop Server", icon="CANCEL")
        else:
            layout.label(text="Server stopped", icon="UNLINKED")
            layout.operator("substrate.start_server", text="Start Server", icon="PLAY")


class SUBSTRATE_OT_StartServer(bpy.types.Operator):
    bl_idname = "substrate.start_server"
    bl_label = "Start Substrate Server"

    def execute(self, context):
        if start_server():
            self.report({"INFO"}, f"Substrate server started on {HOST}:{PORT}")
        else:
            self.report({"WARNING"}, "Server already running")
        return {"FINISHED"}


class SUBSTRATE_OT_StopServer(bpy.types.Operator):
    bl_idname = "substrate.stop_server"
    bl_label = "Stop Substrate Server"

    def execute(self, context):
        stop_server()
        self.report({"INFO"}, "Substrate server stopped")
        return {"FINISHED"}


# ── Registration ─────────────────────────────────────────────────────────────

classes = (
    SUBSTRATE_PT_ServerPanel,
    SUBSTRATE_OT_StartServer,
    SUBSTRATE_OT_StopServer,
)

def register():
    for cls in classes:
        bpy.utils.register_class(cls)

def unregister():
    stop_server()
    for cls in reversed(classes):
        bpy.utils.unregister_class(cls)

if __name__ == "__main__":
    register()
