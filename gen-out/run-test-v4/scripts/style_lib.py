"""V4 style as a library: cel shading, inverted-hull outline, key/rim light + AO, brush noise + earthy palette.

    import style_lib; style_lib.apply({"toon","outline","light","paint"}, cam, part_names)
Call after the camera is framed (outline width is derived from the ortho scale) and before splitting meshes.
"""
import bpy, math
import render_lib as R

FLAGS = set()
INK = (0x3a / 255, 0x2c / 255, 0x22 / 255)


def srgb_to_lin(c):
    return tuple(((x + 0.055) / 1.055) ** 2.4 if x > 0.04045 else x / 12.92 for x in c)


INK_LIN = srgb_to_lin(INK)
RIM_FROM = (0.31, 0.85, 0.42)  # direction the rim light comes from (world)
HAIR_LIN = srgb_to_lin((0x2e / 255, 0x20 / 255, 0x18 / 255))


def mixc(N, blend, fac=1.0):
    """RGBA Mix node; returns (node, factor, A, B, result) sockets picked by type (names are ambiguous)."""
    m = N.new("ShaderNodeMix")
    m.data_type = "RGBA"
    m.blend_type = blend
    ins = [i for i in m.inputs if i.type == "RGBA"]
    f = m.inputs[0]
    f.default_value = fac
    res = next(o for o in m.outputs if o.type == "RGBA")
    return m, f, ins[0], ins[1], res


def toonify(mat):
    nt = mat.node_tree
    N, L = nt.nodes, nt.links
    p = next(n for n in N if n.bl_idname == "ShaderNodeBsdfPrincipled")
    out = next(n for n in N if n.bl_idname == "ShaderNodeOutputMaterial")
    # albedo socket (texture x vertex color mix) and alpha
    bl = p.inputs["Base Color"].links
    if bl:
        albedo = bl[0].from_socket
    else:
        rgb = N.new("ShaderNodeRGB")
        rgb.outputs[0].default_value = p.inputs["Base Color"].default_value
        albedo = rgb.outputs[0]
    al = p.inputs["Alpha"].links
    nl = p.inputs["Normal"].links
    is_hair = mat.name.startswith("MI_Hair")

    if "paint" in FLAGS:
        if is_hair:
            rgb = N.new("ShaderNodeRGB")
            rgb.outputs[0].default_value = HAIR_LIN + (1,)
            # keep the strand detail from the texture as a light modulation
            bw = N.new("ShaderNodeRGBToBW")
            L.new(albedo, bw.inputs[0])
            _, f, a, b, res = mixc(N, "MULTIPLY", 0.35)
            L.new(rgb.outputs[0], a); L.new(bw.outputs[0], b)
            albedo = res
        # earthy palette: desaturate, darken, pull toward warm brown
        hsv = N.new("ShaderNodeHueSaturation")
        hsv.inputs["Saturation"].default_value = 0.72
        hsv.inputs["Value"].default_value = 0.86
        L.new(albedo, hsv.inputs["Color"])
        _, f, a, b, res = mixc(N, "MIX", 0.14)
        b.default_value = srgb_to_lin((0x6b / 255, 0x52 / 255, 0x3c / 255)) + (1,)
        L.new(hsv.outputs[0], a)
        albedo = res
        # brush / paper grain: anisotropic noise in rest-pose object space (sticks to the cloth, no swimming)
        tc = N.new("ShaderNodeTexCoord")
        mp = N.new("ShaderNodeMapping")
        mp.inputs["Scale"].default_value = (90, 90, 18)
        L.new(tc.outputs["Object"], mp.inputs["Vector"])
        nz = N.new("ShaderNodeTexNoise")
        nz.inputs["Scale"].default_value = 1.0
        nz.inputs["Detail"].default_value = 6.0
        nz.inputs["Distortion"].default_value = 0.6
        L.new(mp.outputs[0], nz.inputs["Vector"])
        mr = N.new("ShaderNodeMapRange")
        mr.inputs["To Min"].default_value = 0.86
        mr.inputs["To Max"].default_value = 1.10
        L.new(nz.outputs["Fac"], mr.inputs["Value"])
        _, f, a, b, res = mixc(N, "MULTIPLY", 1.0)
        L.new(albedo, a)
        L.new(mr.outputs["Result"], b)
        albedo = res

    if "toon" not in FLAGS:
        L.new(albedo, p.inputs["Base Color"])
        return

    # lighting term: white diffuse -> Shader to RGB -> brightness
    dif = N.new("ShaderNodeBsdfDiffuse")
    dif.inputs["Color"].default_value = (1, 1, 1, 1)
    # smooth geometry normal on purpose: normal maps break the cel bands into speckles
    s2r = N.new("ShaderNodeShaderToRGB")
    L.new(dif.outputs[0], s2r.inputs[0])
    bw = N.new("ShaderNodeRGBToBW")
    L.new(s2r.outputs["Color"], bw.inputs[0])
    light = bw.outputs[0]
    if "light" in FLAGS:
        ao = N.new("ShaderNodeAmbientOcclusion")
        ao.inputs["Distance"].default_value = 0.12
        mul = N.new("ShaderNodeMath"); mul.operation = "MULTIPLY"
        aom = N.new("ShaderNodeMapRange")  # soften: AO 0..1 -> 0.45..1
        aom.inputs["To Min"].default_value = 0.45
        L.new(ao.outputs["AO"], aom.inputs["Value"])
        L.new(light, mul.inputs[0]); L.new(aom.outputs["Result"], mul.inputs[1])
        light = mul.outputs[0]
    ramp = N.new("ShaderNodeValToRGB")
    cr = ramp.color_ramp
    cr.interpolation = "CONSTANT"
    cr.elements[0].position = 0.0
    cr.elements[0].color = (0.50, 0.55, 0.72, 1)   # cool shadow (never black)
    cr.elements[1].position = 0.40
    cr.elements[1].color = (0.80, 0.80, 0.84, 1)   # mid tone
    e = cr.elements.new(0.68)
    e.color = (1.04, 0.98, 0.90, 1)                # warm light
    L.new(light, ramp.inputs["Fac"])
    _, f, a, b, col = mixc(N, "MULTIPLY", 1.0)
    L.new(albedo, a); L.new(ramp.outputs["Color"], b)
    if "light" in FLAGS:
        # rim: silhouette band (facing ratio) restricted to surfaces turned toward the rim light (behind the back)
        lw = N.new("ShaderNodeLayerWeight")
        lw.inputs["Blend"].default_value = 0.35
        edge = N.new("ShaderNodeMath"); edge.operation = "GREATER_THAN"
        edge.inputs[1].default_value = 0.62
        L.new(lw.outputs["Facing"], edge.inputs[0])
        geo = N.new("ShaderNodeNewGeometry")
        dot = N.new("ShaderNodeVectorMath"); dot.operation = "DOT_PRODUCT"
        dot.inputs[1].default_value = RIM_FROM
        L.new(geo.outputs["Normal"], dot.inputs[0])
        side = N.new("ShaderNodeMath"); side.operation = "GREATER_THAN"
        side.inputs[1].default_value = 0.45
        L.new(dot.outputs["Value"], side.inputs[0])
        rimf = N.new("ShaderNodeMath"); rimf.operation = "MULTIPLY"
        L.new(edge.outputs[0], rimf.inputs[0]); L.new(side.outputs[0], rimf.inputs[1])
        rims = N.new("ShaderNodeMath"); rims.operation = "MULTIPLY"
        rims.inputs[1].default_value = 0.25
        L.new(rimf.outputs[0], rims.inputs[0])
        _, f, a, b, res = mixc(N, "SCREEN", 0.0)
        b.default_value = (1.0, 0.80, 0.55, 1)
        L.new(rims.outputs[0], f)
        L.new(col, a)
        col = res
    em = N.new("ShaderNodeEmission")
    L.new(col, em.inputs["Color"])
    final = em.outputs[0]
    if al:
        tr = N.new("ShaderNodeBsdfTransparent")
        mix = N.new("ShaderNodeMixShader")
        L.new(al[0].from_socket, mix.inputs["Fac"])
        L.new(tr.outputs[0], mix.inputs[1]); L.new(final, mix.inputs[2])
        final = mix.outputs[0]
    L.new(final, out.inputs["Surface"])


def apply(flags, cam, part_names, outline_px=3.0):
    global FLAGS
    FLAGS = set(flags)
    sc = bpy.context.scene
    sun = bpy.data.objects["Key"]
    for m in bpy.data.materials:
        if m.use_nodes and any(n.bl_idname == "ShaderNodeBsdfPrincipled" for n in m.node_tree.nodes):
            toonify(m)

    # ------------------------------------------------------------------ lights
    world_bg = sc.world.node_tree.nodes["Background"]
    if "toon" in FLAGS:
        world_bg.inputs["Strength"].default_value = 0.3   # lighting term then spans ~0.24-0.92 (measured)
    if "light" in FLAGS:
        # key: from the viewer side, in front of the character and above
        sun.rotation_euler = (math.radians(40), 0, math.radians(-55))
        sun.data.energy = 3.0
        sun.data.use_shadow = False
        rim = bpy.data.objects.new("Rim", bpy.data.lights.new("Rim", "SUN"))
        sc.collection.objects.link(rim)
        rim.data.energy = 2.0
        rim.data.color = (1.0, 0.85, 0.65)
        rim.data.use_shadow = False
        rim.rotation_euler = (math.radians(65), 0, math.radians(160))  # from behind the back, slightly far side, above
        if hasattr(sc.eevee, "fast_gi_distance"):
            sc.eevee.fast_gi_distance = 0.2

    # ------------------------------------------------------------------ outline (inverted hull)
    if "outline" in FLAGS:
        ink = bpy.data.materials.new("Ink")
        ink.use_nodes = True
        ink.use_backface_culling = True
        nt = ink.node_tree
        for n in list(nt.nodes):
            nt.nodes.remove(n)
        em = nt.nodes.new("ShaderNodeEmission")
        em.inputs["Color"].default_value = INK_LIN + (1,)
        out = nt.nodes.new("ShaderNodeOutputMaterial")
        nt.links.new(em.outputs[0], out.inputs["Surface"])
        # 2.5 px at the final size: ortho_scale spans the frame height (832 px)
        px = cam.data.ortho_scale / R.H
        thick = outline_px * px
        for name in part_names:
            if name in ("Head_Eyes", "Head_Eyebrows"):
                continue
            o = bpy.data.objects[name]
            o.data.materials.append(ink)
            s = o.modifiers.new("Outline", "SOLIDIFY")
            s.thickness = thick * (0.6 if name.startswith("Head_Hair") else 1.0)
            s.offset = 1.0
            s.use_flip_normals = True
            s.use_rim = False
            s.material_offset = len(o.data.materials) - 1
            s.material_offset_rim = len(o.data.materials) - 1
            s.use_quality_normals = True

