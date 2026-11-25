import bpy, bmesh, numpy as np, colorsys, math
from mathutils import Vector

def load(glb):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=glb)
    return {o.name: o for o in bpy.context.scene.objects if o.type == 'MESH'}

def tex_pixels(me):
    img = None
    for n in me.materials[0].node_tree.nodes:
        if n.type == 'TEX_IMAGE': img = n.image
    W, H = img.size
    return np.array(img.pixels[:]).reshape(H, W, 4), W, H

def join(objs, name):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs: o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join(); o = bpy.context.view_layer.objects.active; o.name = name
    return o

def weld(o):
    bm = bmesh.new(); bm.from_mesh(o.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
    bm.to_mesh(o.data); bm.free(); o.data.update()

def face_data(o):
    """per face: world centroid, world normal, lum, sat (texture of that face's material)"""
    me = o.data; mw = o.matrix_world; nm = mw.to_3x3().inverted().transposed()
    texs = {}
    uv = me.uv_layers.active.data
    C, N, L, Sa = [], [], [], []
    for p in me.polygons:
        mi = p.material_index
        if mi not in texs:
            m = me.materials[mi]; img = None
            for n in m.node_tree.nodes:
                if n.type == 'TEX_IMAGE': img = n.image
            W, H = img.size; texs[mi] = (np.array(img.pixels[:]).reshape(H, W, 4), W, H)
        px, W, H = texs[mi]
        us = [uv[i].uv for i in p.loop_indices]
        u = sum(x[0] for x in us) / len(us); v = sum(x[1] for x in us) / len(us)
        c = px[int(v * H) % H, int(u * W) % W, :3]
        C.append(tuple(mw @ p.center)); N.append(tuple((nm @ p.normal).normalized()))
        L.append(float(c @ np.array([0.2126, 0.7152, 0.0722]))); Sa.append(colorsys.rgb_to_hsv(*c)[1])
    return np.array(C), np.array(N), np.array(L), np.array(Sa)

def adjacency(o):
    me = o.data; ef = {}
    for p in me.polygons:
        for k in p.edge_keys: ef.setdefault(k, []).append(p.index)
    adj = [[] for _ in me.polygons]
    for fs in ef.values():
        for a in fs:
            for b in fs:
                if a != b: adj[a].append(b)
    return adj

def smooth(mask, adj, it=3):
    m = mask.copy()
    for _ in range(it):
        n = m.copy()
        for i, nb in enumerate(adj):
            if nb:
                s = sum(m[j] for j in nb)
                if s * 2 > len(nb) + 1: n[i] = True
                elif s * 2 < len(nb) - 1: n[i] = False
        m = n
    return m

def components(mask, adj):
    seen = set(); comps = []
    for i in np.nonzero(mask)[0]:
        if i in seen: continue
        st = [i]; seen.add(i); c = []
        while st:
            f = st.pop(); c.append(f)
            for g in adj[f]:
                if mask[g] and g not in seen: seen.add(g); st.append(g)
        comps.append(c)
    return comps

def extract(o, keep, name):
    """copy o keeping faces where keep[i] is True"""
    n = o.copy(); n.data = o.data.copy(); n.name = name; n.data.name = name
    bpy.context.scene.collection.objects.link(n)
    bm = bmesh.new(); bm.from_mesh(n.data); bm.faces.ensure_lookup_table()
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if not keep[f.index]], context='FACES')
    bm.to_mesh(n.data); bm.free(); n.data.update()
    return n
