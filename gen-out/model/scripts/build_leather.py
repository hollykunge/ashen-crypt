"""Add a third outfit "leather" (red lamellar swordsman) to the assembled scene.

blender -b char_sprint.blend -P build_leather.py -- <out.blend>

New objects (all bound to the shared Rig, so they follow the same skeleton):
  Leather_Body        Ranger body copy, procedural dark-red lamellar plates (rows of staggered plates, darker lower edge)
  Leather_Belt_1/2    Ranger belts copy, dark brown
  Leather_Arms        Ranger arms copy, sleeves recolored charcoal (skin untouched)
  Leather_Bracer      Ranger bracer (only shipped in the full-outfit file), recolored red leather
  Leather_Legs        Ranger trousers copy, recolored near-black brown
  Leather_ThighGuard  NEW: plates cut from the trouser surface (outer + front thigh), pushed out and thickened, red leather
  Leather_Boots       Ranger boots copy, recolored red leather (metal kept by saturation mask)
  Leather_Pauldron_L/R  Ranger pauldron (left only in the pack) + a mirrored copy for the right shoulder, red leather
"""
import bpy, bmesh, sys, os
from mathutils import Vector

OUT = sys.argv[sys.argv.index("--") + 1]
OUTFIT_FILE = (r"D:\quaternius\Outfits_Fantasy_Standard\Modular Character Outfits - Fantasy[Standard]"
               r"\Exports\glTF (Godot-Unreal)\Outfits\Male_Ranger.gltf")
rig = bpy.data.objects["Rig"]
col = bpy.data.collections["Parts"]


def srgb(h):
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple(((x + 0.055) / 1.055) ** 2.4 if x > 0.04045 else x / 12.92 for x in c) + (1.0,)


RED = srgb("7a2e24")
RED_DARK = srgb("4e1c17")
CHARCOAL = srgb("2c2826")
TROUSER = srgb("2a211c")
BELT = srgb("3b2818")


def dup(src_name, new_name):
    s = bpy.data.objects[src_name]
    o = s.copy()
    o.data = s.data.copy()
    o.name = new_name
    o.data.name = new_name
    col.objects.link(o)
    o.hide_render = o.hide_viewport = False
    return o


def principled_mat(name):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    return m, m.node_tree.nodes["Principled BSDF"]


def recolor(o, slot_index, target, keep=0.18, sat_mask=False):
    """Copy the slot's material and recolor it: luminance of the original albedo x target color (keeps texture detail)."""
    src = o.data.materials[slot_index]
    m = src.copy()
    m.name = f"{o.name}_M{slot_index}"
    o.data.materials[slot_index] = m
    nt = m.node_tree
    N, L = nt.nodes, nt.links
    p = next(n for n in N if n.bl_idname == "ShaderNodeBsdfPrincipled")
    link = p.inputs["Base Color"].links[0]
    albedo = link.from_socket
    bw = N.new("ShaderNodeRGBToBW"); L.new(albedo, bw.inputs[0])
    gain = N.new("ShaderNodeMath"); gain.operation = "MULTIPLY"; gain.inputs[1].default_value = 2.2
    L.new(bw.outputs[0], gain.inputs[0])
    tint = N.new("ShaderNodeMix"); tint.data_type = "RGBA"; tint.blend_type = "MULTIPLY"
    c_in = [i for i in tint.inputs if i.type == "RGBA"]
    tint.inputs[0].default_value = 1.0
    c_in[0].default_value = target
    L.new(gain.outputs[0], c_in[1])
    res = next(s for s in tint.outputs if s.type == "RGBA")
    out = res
    blend = N.new("ShaderNodeMix"); blend.data_type = "RGBA"; blend.blend_type = "MIX"
    b_in = [i for i in blend.inputs if i.type == "RGBA"]
    L.new(res, b_in[0]); L.new(albedo, b_in[1])
    if sat_mask:  # keep grey metal (buckles) close to the original: low saturation -> original color
        sep = N.new("ShaderNodeSeparateColor"); sep.mode = "HSV"
        L.new(albedo, sep.inputs[0])
        inv = N.new("ShaderNodeMapRange")
        inv.inputs["From Min"].default_value = 0.08; inv.inputs["From Max"].default_value = 0.25
        inv.inputs["To Min"].default_value = 0.9; inv.inputs["To Max"].default_value = keep
        L.new(sep.outputs[1], inv.inputs["Value"])
        L.new(inv.outputs["Result"], blend.inputs[0])
    else:
        blend.inputs[0].default_value = keep
    L.new(next(s for s in blend.outputs if s.type == "RGBA"), p.inputs["Base Color"])


def lamellar(o):
    """Procedural lamellar: staggered plate rows in rest-pose (Generated) coordinates, so the pattern sticks to the body."""
    m, p = principled_mat("Leather_Lamellar")
    nt = m.node_tree
    N, L = nt.nodes, nt.links
    tc = N.new("ShaderNodeTexCoord")
    sep = N.new("ShaderNodeSeparateXYZ"); L.new(tc.outputs["Generated"], sep.inputs[0])
    # horizontal coordinate wraps around the torso (front y + side x), vertical = height
    u = N.new("ShaderNodeMath"); u.operation = "MULTIPLY_ADD"
    u.inputs[1].default_value = 0.8
    L.new(sep.outputs["X"], u.inputs[0]); L.new(sep.outputs["Y"], u.inputs[2])
    comb = N.new("ShaderNodeCombineXYZ")
    L.new(u.outputs[0], comb.inputs["X"]); L.new(sep.outputs["Z"], comb.inputs["Y"])
    br = N.new("ShaderNodeTexBrick")
    br.offset = 0.5
    br.inputs["Color1"].default_value = RED
    br.inputs["Color2"].default_value = srgb("6c271f")
    br.inputs["Mortar"].default_value = srgb("1e1210")
    br.inputs["Scale"].default_value = 1.0
    br.inputs["Mortar Size"].default_value = 0.006
    br.inputs["Brick Width"].default_value = 0.11
    br.inputs["Row Height"].default_value = 0.085
    L.new(comb.outputs[0], br.inputs["Vector"])
    # each row darkens toward its lower edge (overlapping plates)
    rowf = N.new("ShaderNodeMath"); rowf.operation = "DIVIDE"; rowf.inputs[1].default_value = 0.085
    L.new(sep.outputs["Z"], rowf.inputs[0])
    fr = N.new("ShaderNodeMath"); fr.operation = "FRACT"; L.new(rowf.outputs[0], fr.inputs[0])
    shade = N.new("ShaderNodeMapRange")
    shade.inputs["To Min"].default_value = 0.62; shade.inputs["To Max"].default_value = 1.08
    L.new(fr.outputs[0], shade.inputs["Value"])
    mul = N.new("ShaderNodeMix"); mul.data_type = "RGBA"; mul.blend_type = "MULTIPLY"
    ins = [i for i in mul.inputs if i.type == "RGBA"]
    mul.inputs[0].default_value = 1.0
    L.new(br.outputs["Color"], ins[0]); L.new(shade.outputs["Result"], ins[1])
    # rivets: small dots near the top of every plate
    vor = N.new("ShaderNodeTexVoronoi"); vor.inputs["Scale"].default_value = 1.0
    rv = N.new("ShaderNodeMapping"); rv.inputs["Scale"].default_value = (1 / 0.055, 1 / 0.085, 1)
    rv.inputs["Location"].default_value = (0, -0.35, 0)
    L.new(comb.outputs[0], rv.inputs["Vector"]); L.new(rv.outputs[0], vor.inputs["Vector"])
    dot = N.new("ShaderNodeMath"); dot.operation = "LESS_THAN"; dot.inputs[1].default_value = 0.09
    L.new(vor.outputs["Distance"], dot.inputs[0])
    riv = N.new("ShaderNodeMix"); riv.data_type = "RGBA"; riv.blend_type = "MIX"
    rins = [i for i in riv.inputs if i.type == "RGBA"]
    L.new(dot.outputs[0], riv.inputs[0])
    L.new(next(s for s in mul.outputs if s.type == "RGBA"), rins[0])
    rins[1].default_value = srgb("b08a4a")  # brass
    L.new(next(s for s in riv.outputs if s.type == "RGBA"), p.inputs["Base Color"])
    p.inputs["Roughness"].default_value = 0.7
    o.data.materials.clear()
    o.data.materials.append(m)


def red_leather_mat(name, base=RED):
    m, p = principled_mat(name)
    nt = m.node_tree
    nz = nt.nodes.new("ShaderNodeTexNoise"); nz.inputs["Scale"].default_value = 40
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].color = RED_DARK
    ramp.color_ramp.elements[1].color = base
    nt.links.new(nz.outputs["Fac"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], p.inputs["Base Color"])
    return m


# ---------------------------------------------------------------- copies of existing parts
body = dup("Male_Ranger_Body", "Leather_Body"); lamellar(body)
for i in (1, 2):
    b = dup(f"Male_Ranger_Body_Belt_{i}", f"Leather_Belt_{i}"); recolor(b, 0, BELT, keep=0.25, sat_mask=True)
arms = dup("Male_Ranger_Arms", "Leather_Arms"); recolor(arms, 0, CHARCOAL, keep=0.1)
legs = dup("Male_Ranger_Legs", "Leather_Legs"); recolor(legs, 0, TROUSER, keep=0.1)
boots = dup("Male_Ranger_Feet_Boots", "Leather_Boots"); recolor(boots, 0, srgb("a8402f"), keep=0.12, sat_mask=True)

# bracer: only in the full-outfit file
before = set(bpy.data.objects)
bpy.ops.import_scene.gltf(filepath=OUTFIT_FILE)
new = [o for o in bpy.data.objects if o not in before]
br = next(o for o in new if o.name.startswith("Male_Ranger_Arms_Bracer"))
br.name = "Leather_Bracer"
mw = br.matrix_world.copy()
br.parent = rig
br.matrix_world = mw
for m in br.modifiers:
    if m.type == "ARMATURE":
        m.object = rig
for c in br.users_collection:
    c.objects.unlink(br)
col.objects.link(br)
for o in new:
    if o is not br:
        bpy.data.objects.remove(o, do_unlink=True)
recolor(br, 0, srgb("9a3a2c"), keep=0.08)

# pauldrons: left from the pack, right = mirrored copy with _l/_r groups swapped
pl = dup("Male_Ranger_Acc_Pauldron", "Leather_Pauldron_L")
pl.data.materials[0] = red_leather_mat("Leather_Pauldron_Mat")
pr = dup("Leather_Pauldron_L", "Leather_Pauldron_R")
bm = bmesh.new(); bm.from_mesh(pr.data)
for v in bm.verts:
    v.co.x = -v.co.x
bmesh.ops.reverse_faces(bm, faces=bm.faces[:])
bm.to_mesh(pr.data); bm.free()
for g in pr.vertex_groups:
    if g.name.endswith("_l"):
        g.name = g.name[:-2] + "_TMPR"
for g in pr.vertex_groups:
    if g.name.endswith("_r"):
        g.name = g.name[:-2] + "_l"
for g in pr.vertex_groups:
    if g.name.endswith("_TMPR"):
        g.name = g.name[:-5] + "_r"

# ---------------------------------------------------------------- NEW: thigh guards cut from the trouser surface
src = bpy.data.objects["Male_Ranger_Legs"]
tg = dup("Male_Ranger_Legs", "Leather_ThighGuard")
gi = {g.index: g.name for g in tg.vertex_groups}
bm = bmesh.new(); bm.from_mesh(tg.data)
dl = bm.verts.layers.deform.active
keep = set()
for f in bm.faces:
    c = f.calc_center_median()
    if not (0.63 < c.z < 0.92):
        continue
    w = {}
    for v in f.verts:
        for g, val in v[dl].items():
            w[gi[g]] = w.get(gi[g], 0) + val
    dom = max(w, key=w.get) if w else ""
    if dom not in ("thigh_l", "thigh_r"):
        continue
    side = 1 if dom == "thigh_l" else -1
    n = f.normal
    if n.x * side > 0.35 or n.y < -0.45:   # outer thigh or front of the thigh
        keep.add(f)
bmesh.ops.delete(bm, geom=[f for f in bm.faces if f not in keep], context="FACES")
bm.normal_update()
for v in bm.verts:
    v.co += v.normal * 0.016
bm.to_mesh(tg.data); bm.free()
sol = tg.modifiers.new("Plate", "SOLIDIFY")
sol.thickness = 0.008
sol.offset = -1
sol.use_rim = True
# keep the plate thickening before any outline modifier added later (Armature -> Plate)
tg.data.materials.clear()
tg.data.materials.append(red_leather_mat("Leather_ThighGuard_Mat", base=srgb("8a3428")))

# hair: Hair_Buns from the pack is two side buns over a bare crown (not a top knot) -> keep the parted hair,
# just give it a style-neutral name used by the slot table
bpy.data.objects["Head_Hair_SimpleParted"].name = "Head_Hair_Main"

print("LEATHER", [o.name for o in col.objects if o.name.startswith("Leather_")])
bpy.ops.wm.save_as_mainfile(filepath=OUT)
