# ART_SKILL_IMPORT_REPORT —— 《西游：八十一难》技能关键帧动作资产复现 V4

> **状态更新（2026-09-12，Owner 裁定）：TECHNICAL_IMPORT_ACCEPTED / VISUAL_ANIMATION_REJECTED。**
> 技术导入通过；技能动画终验不通过。美术资源已冻结（不重画/不补帧/不重分配），Godot 接入代码与预览器保留为技术基座；VIDEO_OR_GIF 暂不标记 PASS（本地 GIF 经核查为 28 帧动画，Owner 收到单帧 PNG 系上传转换所致，待 V5 重录）。详见 `ART_SKILL_V4_STATUS.md`。以下为原始导入报告存档。

生成时间：2026-09-12
依据：`AI_AGENT_复现指令_V4.md` + `OWNER_验收清单_V4.md`
输入：`西游技能关键帧总包_V4.zip`（303 个条目）+ `西游技能关键帧总表_V4.xlsx`

## 1. 输入与清单

- 解压独立目录：`F:\Zcode projects\西游\_skillpack_v4\`（Godot 项目外，只读）
- 以 `03_文档/西游技能关键帧总表_逐帧清单_V4.csv` 为准（288 行逐帧，含 角色slug / 动作slug / 技能名 / 总帧序号 / 导出帧文件）
- 另有 `西游技能关键帧总表_V4.xlsx`（源总表）与 `逐帧清单_V4.json`，内容与 CSV 一致，未做修改

## 2. 文件落位（指令·三）

| 位置 | 内容 | 数量 |
| --- | --- | --- |
| `res://art/skillsheets/` | 8 张总表大图（01_孙悟空…08_杨戬，1254×1254） | 8 |
| `res://art/frames/<角色slug>/<动作slug>/` | 逐帧 PNG（209×209，保留原文件名） | 288 |
| `res://scenes/skill_preview/skill_gallery.tscn` | 预览场景 | 1 |
| `res://scripts/skill_preview/skill_gallery.gd` | 预览脚本 | 1 |
| `res://scripts/skill_preview/skill_manifest.json` | 由 CSV 生成的运行时清单（帧序严格按 总帧序号） | 1 |

8 个角色：sun_wukong 孙悟空 / tang_sanzang 唐僧 / white_dragon_prince 小白龙人形 / white_dragon_horse 白龙马 / zhu_bajie 猪八戒 / sha_wujing 沙悟净 / nezha 哪吒 / erlang_shen 杨戬。

13 组动作：idle / walk / run / dodge / jump_land / atk_light / atk_heavy / skill_core_1 / skill_core_2 / skill_unlock_1 / skill_unlock_2 / ultimate_charge / finisher（每组 2–3 关键帧，合计 36 帧/角色）。

## 3. 导入设置（指令·四）

- 过滤：Nearest（项目全局 `rendering/textures/canvas_textures/default_texture_filter=0`，场景未覆盖）
- Mipmaps：Off（288 张帧 + 8 张总表图 .import 均为 `mipmaps/generate=false`，已抽查验证）
- 透明：RGBA 原样保留，未转格式、未压缩改写
- 未对任何 PNG 做缩放/锐化/调色/重绘；只复制、整理、建动画

## 4. 动画建立（指令·五）

- 运行时按 `skill_manifest.json` 为每个角色构建 SpriteFrames：13 组动画、帧序严格按 CSV `总帧序号`（即目录内 关键帧01/02/03 顺序）
- 播放速度 8 FPS，全部可循环

## 5. 预览场景（指令·六）

`res://scenes/skill_preview/skill_gallery.tscn`（Godot 4.7.2 实机运行，窗口 1280×720）：

- A/D（或←/→）：切角色；W/S（或↑/↓）：切动作
- J：从头播放；K：暂停；L：循环开关
- HUD 显示：当前角色名（如 孙悟空 · C01）、当前技能名+动作类型+slug（如 定海开山（核心技能）· skill_core_1）、当前关键帧号/动作总帧号（如 关键帧 3/3）与 角色总帧 36、角色 1/8 · 动作 8/13
- 8 角色 idle 同屏网格模式（截图 `SKILL_GALLERY_GRID.png`）演示全部角色

## 6. 验收材料（指令·七）

| 材料 | 路径 | 说明 |
| --- | --- | --- |
| 报告 | `ART_SKILL_IMPORT_REPORT.md`（本文件） | |
| 数量 | `ART_SKILL_COUNTS.json` | 8 / 36 / 288 / 13 / true |
| 主截图 | `SKILL_GALLERY_SCREENSHOT.png` | 实机运行：孙悟空 · skill_core_1 · 关键帧 3/3 |
| 演示 GIF | `SKILL_GALLERY_DEMO.gif` | 实机抓帧 28 张合成（7 组 动作/角色 切换：悟空核心/终结/蓄势、唐僧、八戒、哪吒、杨戬），640×360 |
| 附图 | `SKILL_GALLERY_GRID.png` | 8 角色同屏各自播放 idle |

## 7. 红线自查

- 未调用任何 AI 重画/重生成 ✓（仅 PIL 合成 GIF 时用透明底合成与等比缩小，源 PNG 未动）
- 未替换/未修改任何交付 PNG ✓（复制保留原文件名）
- 未改主色、未丢透明 ✓
- 全部 288 帧来自 `02_逐帧PNG/` 原始交付文件 ✓

## 8. 已知现象（沿用 V2 记录，非本次引入）

个别帧 PNG 顶部/边缘带源总表图相邻格的细条碎片（如孙悟空 idle 帧左缘红条），系源图册网格裁切自带，已如实保留，未修图。
