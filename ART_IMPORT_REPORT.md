# ART_IMPORT_REPORT —— 《西游游戏》全量图片资产接入 V2

生成时间：2026-09-12
执行 Agent：ZCode（本地美术资源导入执行 Agent）
依据：AI_AGENT_全量导入执行指令_V2.txt + OWNER_最终验收清单_V2.md

## 1. 输入

- 输入 ZIP 名称：`西游游戏_图片资产包_V1.zip`（72,843,238 字节，141 个条目）
- 清单：执行包内 `atlas_manifest_V2.csv`（103 条）
- 拆分脚本：执行包内 `split_atlases.py`（原样运行，未修改）
- 解压独立目录：`F:\Zcode projects\西游\_assetpack_v1\`（在 Godot 项目外，解压后只读）

## 2. 原图备份位置与 SHA-256

四张最新正式图册已原样复制到 Godot 项目：

- 备份目录：`res://art_source_exact/`（即 `F:\Zcode projects\西游\wukong-godot\art_source_exact\`）
- 哈希清单：`res://art_source_exact/SHA256SUMS.txt`

| 图册 | SHA-256（前 16 位） |
| --- | --- |
| 可玩角色与NPC_图册.png | 149efe33aebc3df3 |
| 通用小怪阵营_图册.png | 5d8e8214cda06d63 |
| Boss图册_A_前中期.png | 1ff3d85ec756e370 |
| Boss图册_B_后期群像.png | 597acc8cdce506e5 |

完整性复核：从原始 ZIP 内重新读取 4 张图册字节计算哈希，与备份逐一比对，**全部一致**（SOURCE_UNMODIFIED=True）。

## 3. 拆分结果（B 步）

命令：`python split_atlases.py "…\_assetpack_v1" "…\wukong-godot"`
输出：`SPLIT_OK count=103`

| 目录 | 数量 | 要求 |
| --- | --- | --- |
| `res://art/characters/` | 25 | 25 ✓ |
| `res://art/enemies/` | 30 | 30 ✓ |
| `res://art/bosses/` | 48 | 48 ✓ |
| 合计 | **103** | 103 ✓ |

说明：仅做无损网格裁切 + 裁掉全透明边缘；Boss 版哪吒/杨戬与普通版为不同资产，未去重；未做缩放/锐化/降噪/调色/重生成；未转 JPG；未删 Alpha。

## 4. Pixelorama .pxo（C 步）

- Pixelorama 已安装：`D:\Pixelorama\Pixelorama.exe`（v1.2.1-stable）
- 已创建工作目录：`res://art/pixelorama/characters/`、`res://art/pixelorama/enemies/`、`res://art/pixelorama/bosses/`
- CLI 探测：Pixelorama 官方 CLI（v1.2）仅支持"导出已有 .pxo"（--export/-e 等），**没有**"打开 PNG 另存 .pxo"的命令行参数；随后尝试 GUI 自动化（打开对话框+输入路径）时，检测到 Owner 本人在本机实时操作（前台为正在输入的浏览器窗口），为避免与用户抢键盘/鼠标，立即停止了 GUI 自动化。
- 结论：**PIXELORAMA_PXO=MANUAL_PENDING（已生成 .pxo 数量：0）**，未伪造任何 .pxo。
- 后续 Owner 手动流程（5 分钟）：打开 Pixelorama → File > Open 打开 `res://art/{characters,bosses}/<slug>.png` → Ctrl+S 另存到 `res://art/pixelorama/<组>/<slug>.pxo`，共 10 个：sun_wukong、tang_sanzang、white_dragon_human、zhu_bajie、sha_wujing、nezha、erlang_shen、bull_demon_king、yellow_wind_king、nine_headed_bird。Godot 接入不受影响（.pxo 非运行必需）。

## 5. Godot 接入（D 步）

- Godot 项目路径：`F:\Zcode projects\西游\wukong-godot`（Godot 4.7.2.stable，GL Compatibility）
- 项目全局过滤已是 Nearest：`rendering/textures/canvas_textures/default_texture_filter=0`
- 新 PNG 通过 `--headless --import` 完成导入，`ResourceLoader.exists("res://art/...")` 全部可用
- 未通过重新保存图片调整大小，仅调 `Sprite2D.scale` / `TextureRect` 布局
- 画廊场景：`res://scenes/art_gallery.tscn` + `res://scripts/art_gallery.gd`
  - 三组展示：characters(25) / enemies(30) / bosses(48)，共 103 张，每张下方显示 slug 名称
  - ←/→ 或 1/2/3 切组，PgUp/PgDn 与滚轮滚动；深色棋盘格背景，透明可见
  - 自动截图模式已验证：characters 整页 25 张同屏、bosses 组 32 张同屏

## 6. 游戏最小试接入（E 步）

接入方式：保留原渲染 fallback（assets/art/heroes → assets/art/enemies → 48px 图集），仅在其上新增 5 条"正式 PNG 覆盖"：

| 要求 | 正式 PNG | 游戏接入点 | 验证 |
| --- | --- | --- | --- |
| 唐僧 | `art/characters/tang_sanzang.png` | `player.gd` hero="tang" | 真机冒烟日志 `trial override: hero:tang` ×7 |
| 孙悟空 | `art/characters/sun_wukong.png` | `player.gd` hero="wukong" | 真机冒烟日志 ×6（切英雄时） |
| 狼妖 | `art/enemies/wolf_demon.png` | `enemy.gd` kind="wolf" | 真机冒烟日志 ×16628（每次刷怪） |
| 黄风怪 | `art/bosses/yellow_wind_king.png` | `boss.gd`（章节"黄风岭/Boss 黄风大圣"） | 真机冒烟日志 `boss:黄风岭` ×1（Boss 战触发） |
| 牛魔王 | `art/bosses/bull_demon_king.png` | `boss.gd`（按 Boss 名映射；主游戏暂无牛魔王章节，于冒烟验证场景以正式 boss.gd 渲染） | 冒烟场景日志 `boss:牛魔王` ✓ |

- 修改文件：`scripts/sprite_lib.gd`（新增 ART_TRIAL 表 + fit_scale）、`scripts/player.gd`、`scripts/enemy.gd`、`scripts/boss.gd`；新增 `scripts/art_backdrop.gd`、`scripts/art_gallery.gd`、`scripts/art_smoke.gd`、`scenes/art_gallery.tscn`、`scenes/art_smoke.tscn`
- 大小归一：新 PNG 约 208–256px，运行时按 `fit_scale()` 只调 Sprite2D.scale 折算到原 48px 图集格基准，不改源图
- 真机整局回归：`main.tscn --smoke`（headless，6 倍速）→ `pass=true`（12 章全通、victory、30716 击杀、收服 Boss、存档往返 OK），日志：`evidence/art-g15-main-smoke.log`、`evidence/art-g15-main-smoke2.log`

## 7. 验收材料（F 步）

| 材料 | 路径 | 状态 |
| --- | --- | --- |
| 导入报告 | `ART_IMPORT_REPORT.md`（本文件） | ✓ |
| 画廊截图 | `ART_GALLERY_SCREENSHOT.png`（characters 25 张同屏+slug；另附 `_enemies` 30 张、`_bosses` 32 张、`_bosses_p2` 16 张，103 张全覆盖） | ✓ 独立评审 PASS |
| 冒烟截图 | `ART_SMOKE_SCREENSHOT.png`（唐僧/孙悟空/狼妖/黄风怪/牛魔王 同屏，正式 player.gd/enemy.gd/boss.gd 运行时渲染） | ✓ 独立评审 PASS |
| 数量 JSON | `ART_IMPORT_COUNTS.json` | ✓ 25/30/48/103/false |
| 视觉复查 | `ART_VISUAL_REVIEW_REQUIRED.md`（5 条，只列问题未重画） | ✓ |

- 测试场景路径：`res://scenes/art_gallery.tscn`（画廊）、`res://scenes/art_smoke.tscn`（5 图冒烟）
- 截图为 Godot 4.7.2 实际运行截图（窗口 1280×720，项目 640×360 canvas）

## 8. 是否修改源 PNG

**否（NO）。** 未覆盖/修改任何源 PNG；四张图册哈希与 ZIP 原始字节一致；103 张拆分 PNG 均为首次派生输出；`_assetpack_v1` 解压目录只读使用。
