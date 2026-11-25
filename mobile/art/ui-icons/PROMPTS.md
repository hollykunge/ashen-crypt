# 界面图标出图提示词

现在这批（raw/sheet-1～4）是用 Codex 桌面版自带的命令行 `codex exec` 调内置出图生成的，每张一次就出好了。
重出某张：把对应提示词交给 `codex exec`，让它把生成的 PNG 复制到 `raw/` 下同名文件，再跑切图。

游戏里约 24 个按钮图标，现在是代码拼的线条。按下面 4 段提示词各出一张图（每张 3 列 × 2 行，6 个图标），
存进 `mobile/art/ui-icons/raw/`，文件名 `sheet-1.png` … `sheet-4.png`，然后跑切图脚本（见最后）。

## 出图要求（四张都一样）

- 尺寸 **1536 × 1024**（横版 3:2），3 列 × 2 行，每格 512 × 512，图标居中，四周留白约 15%。
- 底色 **纯白 #FFFFFF**，不要纸纹、不要边框、不要格线、不要阴影、不要文字。切图时白底会抠成透明。
- 每格只画一个物件，物件之间不相连。
- 出得不满意的某一格可以单独重出一张 512 × 512，命名 `<图标名>.png` 放进 `raw/`，会覆盖图集里那一格。

## 共用风格段（每段提示词都已包含）

> Hand-drawn Chinese ink-brush game UI icons on a pure white background. Each icon is a single object drawn with confident sumi-e brush strokes in dark sepia-brown ink (#3a2c22), varying stroke weight from thick to hair-thin, slight dry-brush texture at stroke ends, a few small cinnabar red (#9b4a36) accents only. Flat, no gradients, no glow, no drop shadow, no frame, no background shapes, no text or characters. Readable silhouette at 44 pixels. Consistent line weight and scale across all icons. Style of an antique Ming-dynasty woodblock-print and ink-wash manual, matching a dark folk-tale wuxia mobile game with aged-paper UI.

---

## sheet-1：普攻和招式

```
Hand-drawn Chinese ink-brush game UI icons on a pure white background, a 3 by 2 grid of six separate icons, each centered in its own equal square cell with generous white margin, no grid lines, no text. Each icon is a single object drawn with confident sumi-e brush strokes in dark sepia-brown ink (#3a2c22), varying stroke weight from thick to hair-thin, slight dry-brush texture at stroke ends, a few small cinnabar red (#9b4a36) accents only. Flat, no gradients, no glow, no drop shadow, no frame. Readable silhouette at 44 pixels. Style of an antique Ming-dynasty woodblock-print and ink-wash manual.
Top row, left to right:
1. A Chinese dao saber, single curved broad blade, round guard, wrapped grip, laid diagonally with the tip to the upper right; small red cord tassel at the pommel.
2. A Chinese jian straight double-edged sword, slim blade with a central ridge, small winged guard, laid diagonally with the tip to the upper right; red tassel.
3. A Chinese spear, long shaft diagonal from lower left to upper right, leaf-shaped spearhead, a tuft of red horsehair below the head.
Bottom row, left to right:
4. A Chinese recurved bow held upright with one arrow nocked, string drawn slightly, red fletching.
5. A sweeping crescent sword slash: one bold curved brush stroke arc with a speed-trail of thinner strokes, a small red spark at its tip ("break formation" skill).
6. A Taoist paper talisman strip with a seal script swirl drawn on it and a red square seal stamp, slightly curling ("intimidate" skill).
```

## sheet-2：撤步、操控方式、倍速

```
Hand-drawn Chinese ink-brush game UI icons on a pure white background, a 3 by 2 grid of six separate icons, each centered in its own equal square cell with generous white margin, no grid lines, no text. Each icon is a single object drawn with confident sumi-e brush strokes in dark sepia-brown ink (#3a2c22), varying stroke weight from thick to hair-thin, slight dry-brush texture at stroke ends, a few small cinnabar red (#9b4a36) accents only. Flat, no gradients, no glow, no drop shadow, no frame. Readable silhouette at 44 pixels. Style of an antique Ming-dynasty woodblock-print and ink-wash manual.
Top row, left to right:
1. Retreat / back-step: a cloth shoe stepping backward to the left over a small swirl of dust cloud, with two short motion strokes.
2. Manual control: an open right hand, palm facing the viewer, fingers slightly spread, drawn in brush outline.
3. Assisted control: the same open hand with a small red ribbon-like cloud curling around the wrist, as if guided.
Bottom row, left to right:
4. Fully automatic: a yin-yang taiji disc with a ring of three short curved arrows circling around it, one arrow red.
5. Battle speed x1: one bold brush chevron pointing right.
6. Battle speed x2: two bold brush chevrons pointing right, overlapping slightly.
```

## sheet-3：倍速三档、暂停、离开、声音、返回

```
Hand-drawn Chinese ink-brush game UI icons on a pure white background, a 3 by 2 grid of six separate icons, each centered in its own equal square cell with generous white margin, no grid lines, no text. Each icon is a single object drawn with confident sumi-e brush strokes in dark sepia-brown ink (#3a2c22), varying stroke weight from thick to hair-thin, slight dry-brush texture at stroke ends, a few small cinnabar red (#9b4a36) accents only. Flat, no gradients, no glow, no drop shadow, no frame. Readable silhouette at 44 pixels. Style of an antique Ming-dynasty woodblock-print and ink-wash manual.
Top row, left to right:
1. Battle speed x3: three bold brush chevrons pointing right, the last one red.
2. Pause: two thick upright brush bars side by side, like two bamboo slips.
3. Leave / exit: a traditional Chinese wooden double door half open, with a short arrow stroke leaving through it to the right.
Bottom row, left to right:
4. Sound muted: a small bronze temple bell with a single red diagonal brush stroke across it.
5. Sound on: the same small bronze temple bell with three curved sound-wave strokes to its right.
6. Back: a bold brush arrow pointing left, its tail ending in a curl like a cloud scroll.
```

## sheet-4：前进、行装、告示、连战、天劫、传送

```
Hand-drawn Chinese ink-brush game UI icons on a pure white background, a 3 by 2 grid of six separate icons, each centered in its own equal square cell with generous white margin, no grid lines, no text. Each icon is a single object drawn with confident sumi-e brush strokes in dark sepia-brown ink (#3a2c22), varying stroke weight from thick to hair-thin, slight dry-brush texture at stroke ends, a few small cinnabar red (#9b4a36) accents only. Flat, no gradients, no glow, no drop shadow, no frame. Readable silhouette at 44 pixels. Style of an antique Ming-dynasty woodblock-print and ink-wash manual.
Top row, left to right:
1. Forward: a bold brush arrow pointing right, its tail ending in a curl like a cloud scroll (mirror of a back arrow).
2. Travel pack / equipment: a cloth bundle tied with a knot, hanging from a short wooden carrying stick, a red cord on the knot.
3. Notice: a hanging paper scroll partly unrolled, a few illegible brush marks for writing (no real characters), a red seal in the corner.
Bottom row, left to right:
4. March onward / continuous battle: a triangular war banner on a pole fluttering to the right, red edge trim.
5. Heavenly tribulation: a dark swirling storm cloud with one jagged lightning bolt striking down, the bolt red.
6. Portal: a round Chinese moon gate in a wall, viewed straight on, the opening empty, faint swirl strokes inside.
```

---

## 切图

图放好以后跑（需要 Python 和 Pillow）：

```
python mobile/art/ui-icons/slice.py
```

会把每格抠成透明底、裁边，存成 `mobile/art/ui-icons/<图标名>.png`。游戏里按钮发现有图就用图，没有就还用原来的线条，所以缺几张也不会坏。

| 图 | 格子顺序（左上起，先横后竖） |
| --- | --- |
| sheet-1 | dao、jian、spear、bow、slash、sigil |
| sheet-2 | retreat、manual、assist、auto、speed1、speed2 |
| sheet-3 | speed3、pause、leave、mute、sound、back |
| sheet-4 | forward、pack、notice、march、jie、portal |
