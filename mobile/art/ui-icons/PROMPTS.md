# V6 独立素材

逐项英文提示词见 `raw/v6/prompts.json`。内置图像工具每次生成一个元素，将 prefix、对应描述和 transparent_suffix 依次拼接，开启 transparent_background。若有 exact_prompt_overrides 条目，使用该条目的完整提示词。标题横竖幕布省略透明后缀并关闭透明参数。角色拆件参考旧部件的姿态、铆钉和轮廓。

运行 `python mobile/art/ui-icons/slice.py` 从独立 PNG 重建游戏贴图，依赖 Pillow、NumPy 和 SciPy。按 alpha 包围框裁切，等比生成显示尺寸，完全透明像素填入最近可见边缘色，保留直通 alpha。人物按 registration.json 配准回关节画布。动画以脚底为轴合成，图标之间留透明间距。运行 `python mobile/art/ui-icons/check_edges.py` 生成黑底、品红底与局部 4 倍放大检查图。

按钮两端纹饰约占各自宽度的 13%，标题牌约占 18%。面板在横向 7%、纵向 9% 处切入平直边线。`art_plate.gd` 用原纹理像素给 StyleBoxTexture 定切线，同时按控件高度或角饰尺寸换算画布比例。前景石路的上方 40% 可站立，放置时同时检查前后走位范围。

## 历史出图记录

# 月夜皮影 · 第二版出图记录

以下 9 张原稿均由内置图像生成工具生成，每次均传入 `mobile/art/piying/style-ref.webp`。三张整幅布景采用不透明背景，其余六张图集启用透明背景。`raw/night-*.png` 保存原图，运行 `python mobile/art/ui-icons/slice.py` 可重建运行时使用的纹理。

## raw/night-river.png

Recreate ONLY the unoccupied background landscape of reference, wide panoramic composition, fine distressed woven linen throughout. Remove all puppets, controls, lettering, moon, foreground foliage and HUD. Keep moonlit blue teal layered hills, sweeping arched Chinese stone bridge and warm tiny lanterns and river reflections. Classic antique shadow theatre scenic backdrop, pale mist, textured dusk, no bright daylight.

## raw/night-scenery.png

Transparent game prop atlas, exactly THREE columns by TWO rows, equal cells, separate isolated cutouts with ample clear margins, in reference's antique blue-grey moonlit shadow theatre style. Row 1 luminous textured round full moon; low distant blue-grey mountain ridge; long shallow stone arched bridge with tiny glowing lanterns. Row 2 small dark teal pavilion; dark hanging willow fronds; dark silhouetted reed clump with golden tips. No text or frames.

## raw/night-fittings.png

Transparent game UI atlas exactly THREE columns TWO rows with ample padding, each item isolated centered. Match reference's ornate antique shadow puppet game UI. Top row: blank circular vermilion leather badge thin ornate gold rim; blank long dark red and gilt cloud-ended horizontal nameplate; blank dark ink teal rectangular panel with thin gold edges and cloud corner ornaments. Bottom row: glowing small golden oil lamp with flame; gold-orange crescent flame slash with curling cloud tongues, soft glow; round gold framed side profile portrait of reference's young Chinese straw hat hero. No text anywhere.

## raw/night-glyphs.png

One production game icon atlas, exactly 5 columns x 4 rows uniform grid. Each icon is an isolated GOLD cut leather silhouette ONLY on transparent background, no badges or disks, no text. Large simple gold luminous carved cut-paper forms, readable at 24px, in the reference's shadow puppet style. In order: row1 curved dao sword, straight jian sword, two unused transparent cells, fire crescent. Row2 magic talisman, retreat double arrows, portal arch, pause twin bars, travel boot. Row3 pouch, scroll notice, return arrow left, forward arrow right, exit gate. Row4 sounding gong, muted gong, manual joystick, sword assist, automatic crossed swords. Exactly 20 cells.

## raw/night-title.png

Vertical 9:19.5 title background artwork for this same shadow puppet game. Closely reproduce reference's teal blue-gray weave, parchment moon at upper left, sparse small warm bridge lanterns, middle-distance arched stone bridge and glowing reflections, shadow silhouettes of hanging willow upper left and reeds lower corners. Keep middle open for title text, no text or HUD or characters. Calm illustrated antique linen Chinese shadow theatre. A tiny distant pavilion at the far right. Detailed fine linen, no ink brush painting.

## raw/night-faces.png

Game UI sprite sheet in same reference style. Transparent background. Precisely 3 columns x 2 rows separate centered assets. Top row 3 round gilded portrait frames around Chinese young FEMALE shadow puppet warrior in side profile, respectively jade green armor, cinnabar armor, ochre armor, carved painted leather. Bottom row three golden carved-leather icons: single forward speed chevron, double chevrons, triple chevrons. All equal square cells, lots of space, no letters.

## raw/night-river-portrait.png

Paint a 4:5 slightly vertical scenery plate for a Chinese shadow theatre side-scrolling game. Reference image is strict art direction. Entire upper 53% empty quiet teal-blue fabric sky with delicately fine horizontal/vertical linen weave. Lower half has delicate distant misty mountain silhouettes, at 70% height a very small Chinese multi-arch bridge seen from far across the lake, 4 tiny golden lanterns and soft golden reflections down to bottom. Perspective wide, distant, multiple arches fit within the CENTRAL HALF of the frame. Subtle clouds, low contrast grey-green like the reference. Beautiful natural unlettered cloth. No characters, NO moon, no foreground leaves or framing reeds (added as layers by game), no writing, no Chinese characters or symbols or repeated decorative motifs, no border, no UI. Preserve clear creamy gray middle ground behind figures.

## raw/night-gallery.png

Use this image as the stylistic reference. Gilt details and glowing cut leather in jade, cinnabar, pale gold and lamp black designed to read against a dark teal ground. Isolated objects, transparent atlas, no text or background. Transparent 3 columns x 2 rows sheet of SIX isolated Chinese shadow puppet theatrical busts. Each fits completely in its own equal square cell with 12% margin, no overlap. Head and shoulders, each facing right. Museum-grade cut leather profiles, expressive etched almond eyes and intricate die-cut headdresses. Top row: Erlang Shen third eye golden crown, Jiutian Xuannu indigo phoenix crown, Hou Yi red-robed immortal. Bottom row: Qingniao fairy green feather headdress, Thunder Master dark bearded thunder official with drum, Dianmu vermilion headdress with two small round mirrors. No calligraphy, no words, no background discs.

## raw/night-materials.png

Use this image as the stylistic reference. Gilt details and glowing cut leather in jade, cinnabar, pale gold and lamp black designed to read against a dark teal ground. Isolated objects, transparent atlas, no text or background. Game inventory materials, Chinese shadow puppet theatre knife-carved translucent dyed cowhide. Transparent RGBA 4 x 4 grid of precisely 16 different isolated icons each centered in equal square cell with large 18% clear gutters. Strong readable outline at 24 pixels, deep brown contour and pierced amber or cinnabar patterns; no background, NO tile, no plate, no text, no cast shadow. Read left to right. Row1 short cross-section of wood log with tree rings, green coiled vine, cluster of cinnabar sand granules, lump of charcoal. Row2 ochre angular rock, reddish rolled clay lump, raw dark iron nugget, iron shavings in a curl. Row3 indigo crystal cluster, hexagonal ice core, bronze iron ingot, carved dragon bone. Row4 three pale blue ice granules, polished steel bar, multicolor round alchemy pill, vermilion boss relic medallion. Folk craft materials collected in a fantasy theatre game. Flat silhouettes.

## 第四版界面素材

- `ref-title.webp` → Remove all letters, logo, buttons and text completely from this reference image. Preserve the entire gorgeous landscape 16:9 composition, exactly the moonlit woven teal river landscape with bridge, foreground willow and reeds, golden lantern reflection and youthful Chinese shadow puppet boy on lower right holding lantern. Clean game background.
- `ref-armory.webp` → Transparent sprite atlas, regular 4 columns by 3 rows equal square cells, each object isolated centered with ample margin. Columns exactly tunic, wrist bracers, shin guards, boots. Rows cloth, leather, linked scale armor. Match the reference's finely cut Chinese shadow puppet teal crimson and golden floral perforations, brass pins, bright warm translucent edges. No writing no UI no shadows.
Generate six shadow puppet weapons in a 3-column, 2-row atlas. Top row: three curved dao blades. Bottom row: three straight jian blades. Engraved crimson, jade and gold leather, transparent background.
- `ref-settings.webp` → Transparent UI asset sheet. EXACT 2 columns x 2 rows equal sized cells. Center each item inside its cell, full silhouette, no text anywhere. Upper left: long wide dark red lacquer button with narrow gold double border and ornate gold ruyi terminals copying reference bottom buttons. Upper right: brighter cinnabar selected version. Lower left: grand wider ornamental maroon page title cartouche curling gold cloud terminals as reference top. Lower right: dark teal rectangular panel with thin gold border and cloud corners. Blank centers. Pure transparent background. Landscape 3:2 sheet.
- `ref-weapons.webp` → Keep the entire original landscape composition and decorative golden rod, hanging lanterns, fabric tassels, the two empty matching translucent hanging silk banners with pointed floral bottoms. Remove every weapon, all lettering, all red labels, title, buttons, portrait, pause icon and selected orange glow. Four equally spaced empty gauze banners evenly distributed across the full width. Background painting only, full bleed landscape.
- `ref-title.webp` → Recompose reference into a tall portrait 9:19.5 mobile opening illustration. Woven teal moonlit river with arch bridge, foreground willow/reeds, lantern-carrying shadow puppet boy complete body lower RIGHT in bottom half, red lantern reflection below. Full moon upper right. Keep upper left and middle upper third smooth negative space for title. No text, buttons or UI.
- `ref-settings.webp` → Remove entire UI including panel title controls and all text, leave a clean landscape illustration of the teal moonlit river bridge, moon upper left, foreground willow / reeds, a warm red paper lantern hanging at far right, same painted folk art cloth texture and muted values. Landscape wide 16:9.
- `ref-armory.webp` → Create a character dressing-room painted backdrop, using ONLY the LEFT landscape half of the armory reference as composition. Remove boy, all UI, all text. Square 1:1 closely framed stage: willow sprigs and bright warm full moon upper left, broad stone arched bridge spanning across CENTER at 50 percent image height, lantern reflections in water lower middle. Flat broad grassy rock ledge forming continuous ground centered across bottom 10 percent specifically for a character sprite to stand on. Cool teal and gray mist, hand painted Chinese shadow puppet cloth with warm golden highlights on reeds and water, dark foreground reeds at extreme sides. The bridge should be clearly visible, no big empty sky.
- `ref-weapons.webp` → Two empty gauze banners side by side on one gold rod above the moonlit river. Leave space above for the heading and below for the two buttons.

## FIX-V7 河岸和如意牌

内置 ImageGen 分两次生成，均使用 `transparent_background=true`、PNG、独立元素。原稿保存在 `raw/v7/`。提示词如下。

- 河岸：Landscape game sprite, a single long continuous narrow riverbank walkway for a Chinese shadow puppet side-scroller. 1536x1024 transparent PNG. Across the entire canvas width running off left and right edges exactly horizontally, in middle of transparent canvas a long straight narrow 6:1 strip. Top 78 percent of strip is solid muted petrol jade dyed translucent hide, sparse diagonal hand-incised plank lines, horizontal perspective walkable surface, fine amber lit rim. Bottom 22 percent is thin dark oxblood carved leather fascia with restrained irregular small cutout Chinese meanders, low contrast. Both ends same elevation, no endcaps, no posts, no above-surface objects. Flat handcut folk shadow theater prop, no photograph, subdued relative to hero. isolated on fully transparent background, no backdrop, no ground shadow, no text.
- 如意牌：Single Chinese shadow puppet game primary button plaque, no text. Landscape 1536x1024 native transparent PNG. Center one horizontal low long plaque, width 1400 height 320. 82% of width is completely clear flat deep cinnabar oxblood red leather, fine continuous double antique-gold hairline border. Tiny elegant Chinese ruyi carved gold corner curves confined to outermost 8% of each end. Symmetrical shallow scalloped ends. Readable restrained silhouette, rich warm translucent leather pigmentation, sharply incised foil lines. Front elevation, isolated on fully transparent background, no backdrop, no shadow, no glow, no writing, no flowers, no medallions.

运行 `python mobile/art/ui-icons/raw/v7/prepare.py` 可复现裁边、透明像素邻色填充及边缘检查。两张原稿实际为 1536×1024 和 2172×724，裁边后为 1536×121 和 2103×357，全程保持原生像素比例。河岸交替镜像铺排，共享接边；按钮使用九宫格，两端各占源宽的 8.5%，四种按钮状态共用同一轮廓。
