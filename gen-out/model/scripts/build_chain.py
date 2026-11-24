"""Add a fourth outfit "chain" (链甲: ring mail with steel plates) to the character scene.

blender -b ashen_char_3outfits.blend -P build_chain.py -- [out.blend]   (no out -> save in place; re-running replaces)

New objects (all bound to the shared Rig), built like the leather set (build_leather.py) from existing parts:
  Chain_Body           Ranger body copy (tunic with skirt) in procedural ring mail
  Chain_Belt_1/2       Ranger belts copy, dark leather (metal buckles kept)
  Chain_Arms           Ranger arms copy, sleeves in ring mail (skin untouched)
  Chain_Bracer         Leather bracer copy, steel plate (vambrace)
  Chain_Legs           Ranger trousers copy in ring mail (chausses)
  Chain_Boots          Ranger boots copy, dark leather (metal kept)
  Chain_Pauldron_L/R   Leather pauldron copies (already fitted and weighted by fit_pauldrons.py), steel plate
Ring mail: rings ~1.6 cm across in rest-pose (Generated) coordinates scaled to metres, so the pattern sticks to the body;
each row is offset half a ring, every ring lighter on its upper half (catches the key light), dark gaps between.
"""
import bpy, bmesh, sys
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = argv[0] if argv else bpy.data.filepath
rig = bpy.data.objects["Rig"]
col = bpy.data.collections["Parts"]
RING = 0.016  # ring spacing, metres


def srgb(h):
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple(((x + 0.055) / 1.055) ** 2.4 if x > 0.04045 else x / 12.92 for x in c) + (1.0,)


STEEL = srgb("a3a9ae")
STEEL_LIGHT = srgb("c8cdd0")
GAP = srgb("55585d")
DARK_LEATHER = srgb("2e2520")

# re-running: drop the previous chain set
for o in list(bpy.data.objects):
    if o.name.startswith("Chain_"):
        bpy.data.objects.remove(o, do_unlink=True)
for m in list(bpy.data.materials):
    if m.name.startswith("Chain_") and m.users == 0:
        bpy.data.materials.remove(m)


def dup(src_name, new_name):
    s = bpy.data.objects[src_name]
    o = s.copy()
    o.data = s.data.copy()
    o.name = new_name
    o.data.name = new_name
    col.objects.link(o)
    o.hide_render = o.hide_viewport = False
    return o


def principled(name):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    p = next(n for n in m.node_tree.nodes if n.bl_idname == "ShaderNodeBsdfPrincipled")
    return m, p


def mix_rgba(N, blend="MIX"):
    m = N.new("ShaderNodeMix"); m.data_type = "RGBA"; m.blend_type = blend
    ins = [i for i in m.inputs if i.type == "RGBA"]
    out = next(s for s in m.outputs if s.type == "RGBA")
    return m, m.inputs[0], ins[0], ins[1], out


def ring_mail(o, name):
    """Procedural ring mail on the object's rest-pose surface."""
    m, p = principled(name)
    nt = m.node_tree
    N, L = nt.nodes, nt.links
    co = [v.co for v in o.data.vertices]
    dims = Vector((max(c.x for c in co) - min(c.x for c in co), max(c.y for c in co) - min(c.y for c in co),
                   max(c.z for c in co) - min(c.z for c in co)))
    tc = N.new("ShaderNodeTexCoord")
    mp = N.new("ShaderNodeMapping")
    mp.inputs["Scale"].default_value = dims / RING          # generated 0..1 -> ring units
    L.new(tc.outputs["Generated"], mp.inputs["Vector"])
    sep = N.new("ShaderNodeSeparateXYZ"); L.new(mp.outputs[0], sep.inputs[0])
    row = N.new("ShaderNodeMath"); row.operation = "FLOOR"; L.new(sep.outputs["Z"], row.inputs[0])
    half = N.new("ShaderNodeMath"); half.operation = "MULTIPLY"; half.inputs[1].default_value = 0.5
    L.new(row.outputs[0], half.inputs[0])
    shift = N.new("ShaderNodeCombineXYZ")
    L.new(half.outputs[0], shift.inputs["X"]); L.new(half.outputs[0], shift.inputs["Y"])
    add = N.new("ShaderNodeVectorMath"); add.operation = "ADD"
    L.new(mp.outputs[0], add.inputs[0]); L.new(shift.outputs[0], add.inputs[1])
    fr = N.new("ShaderNodeVectorMath"); fr.operation = "FRACTION"; L.new(add.outputs[0], fr.inputs[0])
    cen = N.new("ShaderNodeVectorMath"); cen.operation = "SUBTRACT"; cen.inputs[1].default_value = (0.5, 0.5, 0.5)
    L.new(fr.outputs[0], cen.inputs[0])
    ln = N.new("ShaderNodeVectorMath"); ln.operation = "LENGTH"; L.new(cen.outputs[0], ln.inputs[0])
    # ring band around radius 0.34 of a cell
    dev = N.new("ShaderNodeMath"); dev.operation = "SUBTRACT"; dev.inputs[1].default_value = 0.34
    L.new(ln.outputs["Value"], dev.inputs[0])
    ab = N.new("ShaderNodeMath"); ab.operation = "ABSOLUTE"; L.new(dev.outputs[0], ab.inputs[0])
    band = N.new("ShaderNodeMapRange")
    band.inputs["From Min"].default_value = 0.07; band.inputs["From Max"].default_value = 0.15
    band.inputs["To Min"].default_value = 1.0; band.inputs["To Max"].default_value = 0.0
    L.new(ab.outputs[0], band.inputs["Value"])
    # upper half of each ring a little lighter
    csep = N.new("ShaderNodeSeparateXYZ"); L.new(cen.outputs[0], csep.inputs[0])
    top = N.new("ShaderNodeMapRange")
    top.inputs["From Min"].default_value = -0.15; top.inputs["From Max"].default_value = 0.3
    L.new(csep.outputs["Z"], top.inputs["Value"])
    _, f1, a1, b1, metal = mix_rgba(N)
    a1.default_value = STEEL; b1.default_value = STEEL_LIGHT
    L.new(top.outputs["Result"], f1)
    _, f2, a2, b2, col_out = mix_rgba(N)
    a2.default_value = GAP
    L.new(metal, b2); L.new(band.outputs["Result"], f2)
    L.new(col_out, p.inputs["Base Color"])
    p.inputs["Metallic"].default_value = 0.6
    p.inputs["Roughness"].default_value = 0.45
    return m


def steel_plate(name):
    m, p = principled(name)
    nt = m.node_tree
    nz = nt.nodes.new("ShaderNodeTexNoise"); nz.inputs["Scale"].default_value = 25
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].color = srgb("5e656b")
    ramp.color_ramp.elements[1].color = srgb("9aa1a6")
    nt.links.new(nz.outputs["Fac"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], p.inputs["Base Color"])
    p.inputs["Metallic"].default_value = 0.8
    p.inputs["Roughness"].default_value = 0.35
    return m


def recolor(o, slot_index, target, keep=0.18):
    """Luminance of the original albedo x target; low-saturation pixels (grey metal buckles) keep their colour."""
    src = o.data.materials[slot_index]
    m = src.copy()
    m.name = f"{o.name}_M{slot_index}"
    o.data.materials[slot_index] = m
    nt = m.node_tree
    N, L = nt.nodes, nt.links
    p = next(n for n in N if n.bl_idname == "ShaderNodeBsdfPrincipled")
    albedo = p.inputs["Base Color"].links[0].from_socket
    bw = N.new("ShaderNodeRGBToBW"); L.new(albedo, bw.inputs[0])
    gain = N.new("ShaderNodeMath"); gain.operation = "MULTIPLY"; gain.inputs[1].default_value = 2.2
    L.new(bw.outputs[0], gain.inputs[0])
    _, f, a, b, tinted = mix_rgba(N, "MULTIPLY")
    f.default_value = 1.0; a.default_value = target
    L.new(gain.outputs[0], b)
    _, f2, a2, b2, out = mix_rgba(N)
    L.new(tinted, a2); L.new(albedo, b2)
    sep = N.new("ShaderNodeSeparateColor"); sep.mode = "HSV"; L.new(albedo, sep.inputs[0])
    inv = N.new("ShaderNodeMapRange")
    inv.inputs["From Min"].default_value = 0.08; inv.inputs["From Max"].default_value = 0.25
    inv.inputs["To Min"].default_value = 0.9; inv.inputs["To Max"].default_value = keep
    L.new(sep.outputs[1], inv.inputs["Value"]); L.new(inv.outputs["Result"], f2)
    L.new(out, p.inputs["Base Color"])


body = dup("Male_Ranger_Body", "Chain_Body")
body.data.materials.clear()
body.data.materials.append(ring_mail(body, "Chain_Mail_Body"))
for i in (1, 2):
    b = dup(f"Male_Ranger_Body_Belt_{i}", f"Chain_Belt_{i}")
    recolor(b, 0, DARK_LEATHER, keep=0.25)
arms = dup("Male_Ranger_Arms", "Chain_Arms")
arms.data.materials[0] = ring_mail(arms, "Chain_Mail_Arms")
legs = dup("Male_Ranger_Legs", "Chain_Legs")
legs.data.materials.clear()
legs.data.materials.append(ring_mail(legs, "Chain_Mail_Legs"))
boots = dup("Male_Ranger_Feet_Boots", "Chain_Boots")
recolor(boots, 0, DARK_LEATHER, keep=0.12)
plate = steel_plate("Chain_Steel_Plate")
for src, new in (("Leather_Bracer", "Chain_Bracer"), ("Leather_Pauldron_L", "Chain_Pauldron_L"),
                 ("Leather_Pauldron_R", "Chain_Pauldron_R")):
    o = dup(src, new)
    o.data.materials.clear()
    o.data.materials.append(plate)

print("CHAIN", sorted(o.name for o in col.objects if o.name.startswith("Chain_")))
bpy.ops.wm.save_as_mainfile(filepath=OUT, relative_remap=True)
print("SAVED", OUT)
