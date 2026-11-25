"""render the fitted body with the slot set: full, body+arms+head (nude), top removed, pants removed; front & 3/4"""
import bpy, sys, math
from mathutils import Vector
a = sys.argv[sys.argv.index("--")+1:]; SLOTS, BODY, OUT = a
bpy.ops.wm.read_factory_settings(use_empty=True); bpy.ops.import_scene.gltf(filepath=SLOTS); bpy.ops.import_scene.gltf(filepath=BODY)
sc = bpy.context.scene; sc.render.engine = "BLENDER_WORKBENCH"; sc.display.shading.light = "STUDIO"; sc.display.shading.color_type = "TEXTURE"
sc.display.shading.show_backface_culling = False
sc.render.resolution_x = sc.render.resolution_y = 400; sc.world = bpy.data.worlds.new("W"); sc.world.color = (0.86, 0.84, 0.8)
ms = {o.name: o for o in sc.objects if o.type == 'MESH'}
print("MESHES", sorted(ms))
cam = bpy.data.objects.new("C", bpy.data.cameras.new("C")); sc.collection.objects.link(cam); sc.camera = cam; cam.data.type = "ORTHO"; cam.data.ortho_scale = 1.1
sets = {"full": None, "nude": {"base_body", "body_head", "body_arm_R", "body_arm_L"},
        "no_top": set(ms) - {"top"}, "no_pants_top": set(ms) - {"top", "pants"}, "no_boots": set(ms) - {"boot_L", "boot_R"}}
for nm, keep in sets.items():
    for o in ms.values(): o.hide_render = keep is not None and o.name not in keep
    for yaw in (90, 50, -90):
        cam.rotation_euler = (math.radians(90), 0, math.radians(yaw)); cam.location = Vector((0, 0, 0)) - (cam.rotation_euler.to_matrix() @ Vector((0, 0, -1))) * 5
        sc.render.filepath = f"{OUT}/{nm}_{yaw}.png"; bpy.ops.render.render(write_still=True)
