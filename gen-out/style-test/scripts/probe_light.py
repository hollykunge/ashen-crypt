# Replace every material with: emission = (white diffuse -> shader to rgb -> bw) / 4, to read the lighting range.
import bpy, sys, os, math
sys.path.insert(0, os.path.dirname(__file__))
import render_lib as R
out = sys.argv[sys.argv.index("--") + 1]
amb = float(sys.argv[sys.argv.index("--") + 2])
cam = R.setup_scene(); R.frame_camera(cam, R.all_part_names(), [4])
sc = bpy.context.scene
sc.world.node_tree.nodes["Background"].inputs["Strength"].default_value = amb
sun = bpy.data.objects["Key"]; sun.rotation_euler = (math.radians(40), 0, math.radians(-55)); sun.data.energy = 3.0
sc.view_settings.view_transform = "Standard"; sc.render.image_settings.color_depth = "16"
for m in bpy.data.materials:
    if not m.use_nodes: continue
    nt = m.node_tree; N, L = nt.nodes, nt.links
    o = next((n for n in N if n.bl_idname == "ShaderNodeOutputMaterial"), None)
    if not o: continue
    d = N.new("ShaderNodeBsdfDiffuse"); s = N.new("ShaderNodeShaderToRGB"); b = N.new("ShaderNodeRGBToBW")
    mth = N.new("ShaderNodeMath"); mth.operation = "DIVIDE"; mth.inputs[1].default_value = 4.0
    e = N.new("ShaderNodeEmission")
    L.new(d.outputs[0], s.inputs[0]); L.new(s.outputs[0], b.inputs[0]); L.new(b.outputs[0], mth.inputs[0]); L.new(mth.outputs[0], e.inputs[0])
    L.new(e.outputs[0], o.inputs["Surface"])
R.show_only(R.objects_for({"head":"bare","torso":"ranger","arms":"ranger","legs":"ranger","feet":"ranger","shoulder":"ranger","hood":"ranger"}))
sc.frame_set(4); R.render_to(out)
