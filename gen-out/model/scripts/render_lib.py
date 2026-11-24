"""Shared render setup: fixed orthographic side camera, flat-ish lighting, transparent background."""
import bpy, math
from mathutils import Vector

W, H = 480, 832

SLOTS = {
    "head":   {"bare": ["Head_Skin", "Head_Eyes", "Head_Eyebrows", "Head_Hair_Main", "Head_Hair_Beard"]},
    "torso":  {"peasant": ["Male_Peasant_Body"], "ranger": ["Male_Ranger_Body", "Male_Ranger_Body_Belt_1", "Male_Ranger_Body_Belt_2"]},
    "arms":   {"peasant": ["Male_Peasant_Arms"], "ranger": ["Male_Ranger_Arms"]},
    "legs":   {"peasant": ["Male_Peasant_Legs"], "ranger": ["Male_Ranger_Legs"]},
    "feet":   {"peasant": ["Male_Peasant_Feet"], "ranger": ["Male_Ranger_Feet_Boots"]},
    "shoulder": {"none": [], "ranger": ["Male_Ranger_Acc_Pauldron"]},
    "hood":   {"none": [], "ranger": ["Male_Ranger_Head_Hood"]},
}


LEATHER = {
    "torso": ["Leather_Body", "Leather_Belt_1", "Leather_Belt_2"],
    "arms": ["Leather_Arms", "Leather_Bracer"],
    "legs": ["Leather_Legs", "Leather_ThighGuard"],
    "feet": ["Leather_Boots"],
    "shoulder": ["Leather_Pauldron_L", "Leather_Pauldron_R"],
}


def enable_leather():
    """Register the 'leather' outfit (only in scenes built with build_leather.py)."""
    for slot, parts in LEATHER.items():
        SLOTS[slot]["leather"] = parts


def all_part_names():
    return sorted({n for s in SLOTS.values() for v in s.values() for n in v})


def objects_for(outfit):
    """outfit: dict slot -> variant"""
    names = []
    for slot, variant in outfit.items():
        names += SLOTS[slot][variant]
    if outfit.get("hood", "none") != "none":  # hood replaces the hair
        names = [n for n in names if n != "Head_Hair_Main"]
    return names


def setup_scene(ortho_scale=2.3, cam_target_z=0.95, facing="right"):
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_EEVEE_NEXT"
    sc.render.resolution_x, sc.render.resolution_y = W, H
    sc.render.resolution_percentage = 100
    sc.render.film_transparent = True
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGBA"
    sc.view_settings.view_transform = "Standard"
    sc.eevee.taa_render_samples = 32

    cam = bpy.data.objects.get("SideCam")
    if cam is None:
        cam = bpy.data.objects.new("SideCam", bpy.data.cameras.new("SideCam"))
        sc.collection.objects.link(cam)
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = ortho_scale
    # character faces -Y in glTF imports; camera on -X/+X side picks the facing direction
    x = -6.0 if facing == "right" else 6.0
    cam.location = Vector((x, 0.0, cam_target_z))
    cam.rotation_euler = (math.radians(90), 0.0, math.radians(-90 if facing == "right" else 90))
    sc.camera = cam

    # world: soft uniform ambient + one key light from camera side, so colors read flat
    world = sc.world or bpy.data.worlds.new("World")
    sc.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    bg.inputs["Color"].default_value = (1, 1, 1, 1)
    bg.inputs["Strength"].default_value = 0.9
    sun = bpy.data.objects.get("Key")
    if sun is None:
        sun = bpy.data.objects.new("Key", bpy.data.lights.new("Key", "SUN"))
        sc.collection.objects.link(sun)
    sun.data.energy = 2.5
    sun.data.use_shadow = False  # parts rendered as separate 2D layers cannot shadow each other
    sun.rotation_euler = (math.radians(50), 0, math.radians(-120 if facing == "right" else 120))
    return cam


def frame_camera(cam, names, frames, margin=1.08, ground_pad=0.04):
    """Fit the fixed ortho camera around every listed mesh over every frame (same framing for all renders)."""
    sc = bpy.context.scene
    show_only(names)
    ymin = zmin = 1e9
    ymax = zmax = -1e9
    for fr in frames:
        sc.frame_set(fr)
        dg = bpy.context.evaluated_depsgraph_get()
        for n in names:
            o = bpy.data.objects[n].evaluated_get(dg)
            me = o.to_mesh()
            mw = o.matrix_world
            for v in me.vertices:
                p = mw @ v.co
                ymin, ymax = min(ymin, p.y), max(ymax, p.y)
                zmin, zmax = min(zmin, p.z), max(zmax, p.z)
            o.to_mesh_clear()
    zmin -= ground_pad
    hspan, vspan = ymax - ymin, zmax - zmin
    cam.data.ortho_scale = max(vspan, hspan * H / W) * margin
    cam.location.y = (ymin + ymax) / 2
    cam.location.z = (zmin + zmax) / 2
    sc["frame_bbox"] = [ymin, ymax, zmin, zmax]
    print("FRAMING y", round(ymin, 3), round(ymax, 3), "z", round(zmin, 3), round(zmax, 3), "ortho", round(cam.data.ortho_scale, 3))


def show_only(names):
    want = set(names)
    for o in bpy.data.objects:
        if o.type == "MESH":
            hide = o.name not in want
            o.hide_render = hide
            o.hide_viewport = hide
            o.is_holdout = False


def render_to(path):
    bpy.context.scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
