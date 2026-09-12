# V5_SKILL_IMPORT_REPORT —— 《西游》主要角色完整技能动作 V5（程序关键帧）

生成时间：2026-09-12
依据：`05_AI_AGENT/AI_AGENT_V5_复现执行指令.md` + `06_Godot_schema/GODOT_V5_KEYFRAME_SCHEMA.md` + `OWNER_V5_验收清单.md`
输入：`西游主要角色完整技能动作关键帧_V5.zip`（24 个条目）

## 1. 数量（与包内 JSON 元数据一致，落盘复核）

| 项 | 值 |
| --- | --- |
| 角色 | 8 |
| 动作 | 83（每角色 10–11 个） |
| 程序关键帧 | 1322 |
| source_tier | PROJECT_CANON / V5_EXPANSION（V5_EXPANSION 标记全部保留） |

`V5_SKILL_COUNTS.json` 已生成，含 `used_base_png_only=true`、`v4_frame_mapping_used=false`。

## 2. 文件落位

| 位置 | 内容 |
| --- | --- |
| `res://art/v5_base/<slug>.png` | 8 张角色基准 PNG 原样复制（SHA-256 与 ZIP 内逐一比对一致，未修改） |
| `res://data/v5_full_keyframes.json` | 关键帧数据原样复制（唯一动画依据） |
| `res://scenes/skill_preview_v5/skill_gallery_v5.tscn` | V5 预览场景 |
| `res://scripts/skill_preview_v5/skill_gallery_v5.gd` | V5 预览脚本 |

V4 的 `res://art/frames/`、`res://scripts/skill_preview/` 等技术基座**原样保留、未引用、未改动**（`V4_FRAME_MAPPING_USED=false`）。

## 3. 实现方式（严格按 V5 schema）

每角色运行时重建 rig 节点树：

```
Rig (48px 身体单位 → 屏幕 280px)
├── VisualRoot            ← body_x/body_y 位置轨道（AnimationPlayer 插值）
│   ├── VFXRoot           ← vfx_intensity 轨道（主色径向光晕，色=角色 primary_color）
│   │   └── (glow Sprite2D)
│   ├── FormOverlay       ← 法相/终结技专属过亮暖色残影，层级随 vfx_intensity
│   └── Sprite2D          ← 基准 PNG 单元 region（不重画）；rotation/scale 轨道
├── HitboxRoot            ← hitbox_active 方法轨道（命中环显示/隐藏 + 白闪）
├── AnimationPlayer       ← 全部 83 动作程序轨道
└── (CameraImpulse)       ← camera_shake 震屏衰减
```

- 方法轨道事件：`hitbox_active`（命中环+白闪）、`invulnerable`（无敌半透明）、`trail_enabled`（主色轨迹线）、`afterimage_count`（2/3 残影发射）、`camera_shake`（2/4/8px 震屏）。
- `hitstop_ms`（40/70/110ms）：命中帧处暂停播放实现顿帧。
- 姿势处理说明：V5 指令"实现"节只要求从 JSON 驱动变换/特效轨道，数据中**没有**逐帧姿势映射字段；为避免重蹈 V4"错误帧映射"，基准姿势取每张基准表首格（与分镜图 KF01 一致），其余表现全部由程序变换/特效完成，未自创任何姿势映射。
- 预览键位：A/D 切角色、W/S 切动作、J 播放、K 暂停、L 循环；HUD 显示角色·slug·主色、动作·分类、**source_tier·解锁来源**、当前 KF/总 KF·时间、命中/无敌/轨迹/残影/震屏/顿帧实时指示灯。

## 4. 验收材料

| 材料 | 路径 | 证据 |
| --- | --- | --- |
| 截图 | `V5_GALLERY_SCREENSHOT.png` | 实机运行：悟空 法天象地（法相）KF12/22，HUD 全项含 source_tier/解锁来源 |
| 网格图 | `V5_GALLERY_GRID.png` | 8 角色同屏 idle 程序动画，各自 primary_color 标签与光晕 |
| 演示 GIF | `V5_SKILL_DEMO.gif` | 实机抓帧 42 张合成（640×360，150ms/帧）；**PIL 复核 GIF89a / is_animated=True / n_frames=42** |
| 报告 | `V5_SKILL_IMPORT_REPORT.md`（本文件） | |
| 数量 | `V5_SKILL_COUNTS.json` | 8/83/1322/true/false |

GIF 演示序列：悟空·法天象地 → 悟空·齐天镇岳终结 → 唐僧·佛光金身 → 八戒·全屏聚怪卷土 → 悟净·流沙漩涡 → 哪吒·三头六臂 → 杨戬·哮天犬逐魂（法相/终结演出层级明显高于普通技能）。

## 5. 红线自查

- 未调用任何 AI 重画/补图 ✓
- 基准 PNG 未修改（ZIP vs 项目 SHA-256 全一致）✓
- 技能名/解锁来源/source_tier 原样展示，未改 ✓；`V5_EXPANSION` 标记保留 ✓
- 透明背景保留（棋盘底可证）✓；Nearest（项目全局 default_texture_filter=0）✓
- 未使用 V4 帧映射/帧文件 ✓
- 每角色严格使用自己的 primary_color（光晕/轨迹/残影/HUD 强调色）✓

## 6. 执行环境说明

应用户要求全程后台执行：Godot 以离屏无边框窗口渲染、viewport 抓帧，未进行任何前台/桌面截图操作，未触碰用户键鼠。
