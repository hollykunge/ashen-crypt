"""Export the character for Godot: one .glb with Rig, every outfit part and every action.

blender -b ashen_char_3outfits.blend -P export_godot.py -- <out.glb> [texture size]

glTF only carries plain image textures, but many materials here are node setups (the leather recolours, the procedural
lamellar / pauldron / thigh-guard leather, vertex-colour masks). So each material slot is first baked to its own
albedo image (Cycles, diffuse colour only, rest pose) and replaced by a Principled BSDF with that image.
Works on a copy in memory: the .blend on disk is not touched (the script never saves it).
"""
import bpy, sys, os

argv = sys.argv[sys.argv.index("--") + 1:]
OUT = os.path.abspath(argv[0])
SIZE = int(argv[1]) if len(argv) > 1 else 1024

sc = bpy.context.scene
rig = bpy.data.objects["Rig"]
rig.data.pose_position = "REST"
sc.render.engine = "CYCLES"
sc.cycles.device = "CPU"
sc.cycles.samples = 4
sc.render.bake.use_pass_direct = False
sc.render.bake.use_pass_indirect = False
sc.render.bake.use_pass_color = True
sc.render.bake.margin = 6

parts = [o for o in bpy.data.objects if o.type == "MESH" and o.parent == rig]
for o in bpy.data.objects:
    o.hide_render = False
    o.hide_viewport = False
    o.hide_set(False)

baked = {}
for o in parts:
    for i, slot in enumerate(o.material_slots):
        m = slot.material
        if m is None:
            continue
        key = (o.name, i)
        size = SIZE if len(o.data.vertices) > 1500 else SIZE // 2
        img = bpy.data.images.new(f"bake_{o.name}_{i}", size, size, alpha=False)
        # bake only the faces of this slot: give the other slots' materials no image target
        mm = m.copy()
        o.material_slots[i].material = mm
        nt = mm.node_tree
        tn = nt.nodes.new("ShaderNodeTexImage")
        tn.image = img
        for n in nt.nodes:
            n.select = False
        tn.select = True
        nt.nodes.active = tn
        others = []
        for j, s2 in enumerate(o.material_slots):
            if j != i and s2.material is not None:
                dummy = s2.material.copy()
                for n in dummy.node_tree.nodes:
                    n.select = False
                d_img = bpy.data.images.new("discard", 8, 8)
                dn = dummy.node_tree.nodes.new("ShaderNodeTexImage")
                dn.image = d_img
                dummy.node_tree.nodes.active = dn
                others.append((j, s2.material, dummy, d_img))
                s2.material = dummy
        bpy.ops.object.select_all(action="DESELECT")
        o.select_set(True)
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.bake(type="DIFFUSE")
        for j, orig, dummy, d_img in others:
            o.material_slots[j].material = orig
            bpy.data.materials.remove(dummy)
            bpy.data.images.remove(d_img)
        # replace the slot material by a plain textured one
        flat = bpy.data.materials.new(f"{o.name}_{i}")
        flat.use_nodes = True
        p = next((n for n in flat.node_tree.nodes if n.bl_idname == "ShaderNodeBsdfPrincipled"), None)
        if p is None:
            p = flat.node_tree.nodes.new("ShaderNodeBsdfPrincipled")
            out = next((n for n in flat.node_tree.nodes if n.bl_idname == "ShaderNodeOutputMaterial"), None) \
                or flat.node_tree.nodes.new("ShaderNodeOutputMaterial")
            flat.node_tree.links.new(p.outputs[0], out.inputs["Surface"])
        t = flat.node_tree.nodes.new("ShaderNodeTexImage")
        t.image = img
        flat.node_tree.links.new(t.outputs["Color"], p.inputs["Base Color"])
        p.inputs["Roughness"].default_value = 0.85
        if "Specular IOR Level" in p.inputs:
            p.inputs["Specular IOR Level"].default_value = 0.1
        o.material_slots[i].material = flat
        bpy.data.materials.remove(mm)
        img.pack()
        baked[key] = img.name
        print("BAKED", o.name, i, m.name, size)

rig.data.pose_position = "POSE"
bpy.ops.object.select_all(action="DESELECT")
for o in parts + [rig]:
    o.select_set(True)
os.makedirs(os.path.dirname(OUT), exist_ok=True)
bpy.ops.export_scene.gltf(
    filepath=OUT, export_format="GLB", use_selection=True,
    export_animations=True, export_animation_mode="ACTIONS", export_force_sampling=True,
    export_image_format="AUTO",
    export_skins=True, export_morph=False, export_apply=False,
)
print("EXPORTED", OUT, os.path.getsize(OUT) // 1024, "KB,", len(baked), "baked slots")
