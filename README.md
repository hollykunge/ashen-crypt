# 余烬地牢 · Ashen Crypt

《余烬地牢》是一款竖屏 2D 像素动作游戏。选择战士、游侠或法师后，迎战五波敌人，拾取材料，再到墓火锻造打造武器、护具和饰品。每个职业有男女两种角色造型和两类武器。装备属性、随机词缀和套装效果会在下一局战斗中生效。

## Godot 手机版

用 Godot 4.7.2 导入 [mobile/project.godot](mobile/project.godot)，再运行工程。选角页的铁砧通往锻造，传送门进入战斗。

导出 iOS 工程时，把 [导出配置示例](mobile/export_presets.cfg.example) 复制为 `mobile/export_presets.cfg`。在 Godot 的 iOS 导出设置中填入自己的 Team ID 和 Bundle Identifier，再使用 Xcode 配置签名。

## 网页原型

在仓库根目录启动静态文件服务，再用浏览器打开 `http://localhost:8000`。

```sh
python3 -m http.server 8000
```

网页入口是 [index.html](index.html)，游戏逻辑位于 [game.js](game.js)。

字体的版权与 SIL 开源字体许可证见 [mobile/art/fonts](mobile/art/fonts)。角色、场景和装备的生成提示词随素材保存在 [mobile/art](mobile/art) 和 [assets](assets) 中。
