"""Render the hero portrait (side-profile bust, facing right, transparent) for the game's UI.

blender -b ashen_char_3outfits.blend -P render_portrait.py -- <out.png> [width height]

Replaces the old painted mobile/art/reference-hero/portrait.png (115x150); rendered at 2x by default.
Peasant tunic, idle pose, V4 style (style_lib).
"""
import bpy, sys, os
sys.path.insert(0, os.path.dirname(__file__))
import render_lib as R
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
OUT = os.path.abspath(argv[0])
W, H = (int(argv[1]), int(argv[2])) if len(argv) > 2 else (230, 300)

rig = bpy.data.objects["Rig"]
act = bpy.data.actions["Idle_Loop"]
rig.animation_data.action = act
if act.slots:
    rig.animation_data.action_slot = act.slots[0]
sc = bpy.context.scene
sc.frame_set(0)

R.enable_leather()
outfit = dict(head="bare", torso="peasant", arms="peasant", legs="peasant", feet="peasant", shoulder="none", hood="none",
              headgear="hat")   # 默认（布衣）戴斗笠，和游戏里一致
names = R.objects_for(outfit)
cam = R.setup_scene()
head = rig.matrix_world @ rig.pose.bones["Head"].head
cam.data.ortho_scale = 0.8
cam.location = Vector((-6.0, head.y - 0.04, head.z - 0.05))
import style_lib
style_lib.apply({"toon", "outline", "light", "paint"}, cam, names, outline_px=2.0)
R.show_only(names)
sc.render.resolution_x, sc.render.resolution_y = W, H
sc.render.resolution_percentage = 100
R.render_to(OUT)
print("PORTRAIT", OUT, W, H)
