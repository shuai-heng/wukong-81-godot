# V6_SKILL_IMPORT_REPORT —— 《西游》主要角色真实姿势关键帧 V6

> **状态更新（2026-09-12，Owner 裁定）：REAL_POSE_PIPELINE_ACCEPTED / SKILL_POSE_SEMANTICS_NEEDS_REVIEW。**
> 技术实现与真实 Pose 切换验收通过，V6 全部实现保留为基座（不回滚）；技能-Pose 语义待 Owner 下一版精确映射补丁，Agent 等待期间不自行重映射/不猜姿势。今后验收视频统一 MP4（H.264，≥720p，连续播放），GIF 不再作为交付物。详见 `ART_SKILL_V4_STATUS.md`。以下为原始导入报告存档。

生成时间：2026-09-12
依据：`05_AI_AGENT/AI_AGENT_V6_真姿势复现执行指令.md` + `06_Godot_schema/GODOT_V6_REAL_POSE_SCHEMA.md`
输入：`西游主要角色真实姿势关键帧_V6.zip`（314 个条目）
执行方式：应用户要求全程后台——Godot 于 Windows 隐藏桌面（CreateDesktop）离屏渲染并自行存图，主桌面零窗口/零抢焦点。

## 1. 数量（与数据文件一致，落盘复核）

| 项 | 值 |
| --- | --- |
| 角色 | 8 |
| 真实姿势 PNG | 288（8 × 36，256×256 RGBA） |
| 程序关键帧 | 1322 |
| 纹理关键帧覆盖 | **1322/1322 = 100%**（每关键帧都按 JSON `pose_file` 离散换装） |
| 被引用的不同姿势 | 288/288（全部用到） |
| source_tier | PROJECT_CANON / V5_EXPANSION（标记原样保留） |

`V6_SKILL_COUNTS.json` 已生成（含 used_existing_pose_art_only=true、v4_frame_mapping_used=false、v5_single_base_pose_disabled=true）。

## 2. 文件落位（指令·文件落位）

| 位置 | 内容 |
| --- | --- |
| `res://art/v6_pose/<slug>/` | 288 张真实姿势 PNG 原样复制（SHA-256 与 ZIP 内逐一比对一致） |
| `res://data/v6_full_keyframes_with_pose.json` | 关键帧+姿势映射数据原样复制（唯一动画依据） |
| `res://scenes/skill_preview_v6/skill_gallery_v6.tscn` | V6 预览场景 |
| `res://scripts/skill_preview_v6/skill_gallery_v6.gd` | V6 预览脚本 |

V4/V5 材料未改动、未引用（V4 帧映射 = false；V5 单一 base PNG 路线已废弃禁用）。

## 3. 实现（指令·实现，严格按 V6 schema）

在 V5 rig 基座（VisualRoot/Sprite2D/AfterimageRoot/VFXRoot/FormOverlay/HitboxRoot/AnimationPlayer/CameraImpulse）上，为每个动作的 AnimationPlayer 增加：

- **`Sprite2D:texture` 离散轨道**（UPDATE_DISCRETE，Texture 不插值）：每个关键帧按 JSON `pose_file` 切换真实姿势 PNG；
- `FormOverlay:texture` 同步离散轨道（法相/终结的过亮残影跟随姿势）；
- V5 全套程序轨道继续：position(body_x/y)、rotation、scale、VFX intensity（线性）、hitbox/invulnerable/shake/trail/afterimage 方法轨道、hitstop 顿帧（40/70/110ms 播放冻结）。

修复记录：切角色时旧 Rig 用 `queue_free()` 延迟一帧释放，导致新节点被自动改名、全部轨道失配（V5 演示 GIF 第 2 段起即受此影响）；V6 已改为 `free()` 立即释放并验证轨道警告清零。

预览键位：A/D 切角色、W/S 切动作、J 播放、K 暂停、L 循环；HUD 显示角色·slug·主色、动作·分类、source_tier·解锁来源、**当前 KF/总 KF·姿势注记**、命中/无敌/轨迹/残影/震屏/顿帧指示灯。

## 4. 验收材料（指令·必须产出）

| 材料 | 路径 | 说明 |
| --- | --- | --- |
| 报告 | `V6_SKILL_IMPORT_REPORT.md`（本文件） | |
| 数量 | `V6_SKILL_COUNTS.json` | 8/288/36/1322/100% |
| 主截图 | `V6_GALLERY_SCREENSHOT.png` | 实机：悟空 法天象地 KF12/22 "金箍棒通天" 真实姿势+法相残影 |
| 姿势联络表 | `V6_POSE_CONTACT_SCREENSHOT.png` | 悟空 36 姿势全量 6×6（POSE_01–36 标签），证明姿势资产完整且形态各异 |
| 网格图 | `V6_GALLERY_GRID.png` | 8 角色同屏 idle 程序动画（姿势+位移双轨道） |
| 演示 GIF | `V6_SKILL_DEMO.gif` | **真多帧动画：GIF89a / is_animated=True / n_frames=153**（PIL 复核），640×360 |

GIF 按指令"强制视觉验收"链路连续录制（每动作取 18%/55%/88% 时间点 3 帧）：

- 孙悟空：平A → 定海重棒 → 毫毛分身 → 七十二变 → 火眼金睛 → 法天象地 → 终结（7 动作全录）
- 唐僧：锡杖平A → 禅音 → 袈裟 → 诵经 → 佛光金身 → 大乘梵音
- 小白龙人形：枪术 → 游龙闪 → 雷霆龙痕 → 化形 → 真龙法相 → 终结
- 白龙马：奔腾 → 闪避 → 龙角冲阵 → 云潮冲阵 → 法相 → 终结
- 八戒：横耙 → 重砸 → 聚怪 → 承伤积怒 → 天蓬镇岳 → 法相 → 终结
- 悟净：宝杖去回 → 流沙 → 水域封锁 → 九骷 → 法相 → 终结
- 哪吒：枪 → 圈 → 绫 → 风火轮 → 三头六臂 → 终结
- 杨戬：戟 → 天眼 → 哮天犬 → 玄功变化 → 万丈法身 → 终结

共 51 动作 153 帧；法相/终结演出层级（过亮残影 + 高 vfx + 顿帧 + 震屏）与普通动作肉眼可辨。

## 5. 红线自查

- 未调用任何 AI 重画/补图 ✓
- 未自猜姿势：288 个姿势全部按 JSON `pose_file` 引用 ✓
- 姿势 PNG 未修改（ZIP vs 项目 SHA-256 全一致）✓
- 透明背景保留（棋盘底可证）；Nearest（项目全局 default_texture_filter=0）✓
- V4 帧映射未使用；V5 单一 base PNG 播动作路线已废弃 ✓
- 每角色严格使用自己的 primary_color（光晕/轨迹/残影/HUD）✓
- 技能名/解锁来源/source_tier 原样展示 ✓
