import bpy, sys, numpy as np, json
a = sys.argv[sys.argv.index("--")+1:]
bpy.ops.wm.read_factory_settings(use_empty=True); bpy.ops.import_scene.gltf(filepath=a[0])
out = {}
for o in bpy.context.scene.objects:
    if o.type != 'MESH': continue
    V = np.array([tuple(o.matrix_world @ v.co) for v in o.data.vertices])
    out[o.name] = {"lo": V.min(0).round(3).tolist(), "hi": V.max(0).round(3).tolist(), "c": V.mean(0).round(3).tolist()}
    if o.name.startswith(("arm_", "body_arm_")):
        tip = V[np.argmax(np.abs(V[:, 1]))]; root = V[np.argmin(np.abs(V[:, 1]))]
        out[o.name]["tip"] = tip.round(3).tolist(); out[o.name]["root"] = root.round(3).tolist()
print("LM", json.dumps(out))
