"""blender -b outfits_rigged.blend -P export_outfits.py -- <out.glb>   (Rig + every slot mesh + every action, rest pose)"""
import bpy, sys, os
from mathutils import Matrix
OUT = os.path.abspath(sys.argv[sys.argv.index("--")+1])
rig = bpy.data.objects["Rig"]; rig.animation_data.action = None
for pb in rig.pose.bones: pb.matrix_basis = Matrix()
for a in bpy.data.actions: a.use_fake_user = True
bpy.ops.object.select_all(action="DESELECT")
for o in bpy.data.objects:
    o.hide_viewport = o.hide_render = False; o.hide_set(False)
    if o is rig or (o.type == "MESH" and o.parent is rig): o.select_set(True)
bpy.context.view_layer.objects.active = rig
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=True,
    export_animations=True, export_animation_mode="ACTIONS", export_force_sampling=True,
    export_image_format="AUTO", export_skins=True, export_morph=False, export_apply=False)
print("EXPORTED", OUT, os.path.getsize(OUT) // 1024, "KB")
