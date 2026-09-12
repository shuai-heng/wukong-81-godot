# 技能关键帧 V4 状态记录（Owner 裁定，2026-09-12）

> **V6.1 最终 Hotfix（2026-09-12 追记）**：悟空终结技边界清理完成——POSE_31/33/34/36 定向边缘 alpha 羽化（左缘岩石垂直切边、POSE_34 顶部头部/背后矩形块均消除；RGB 逐像素不变、映射未动），BEFORE/AFTER 截图 + `V6_1_HOTFIX_FINISH.mp4`（6.90s H.264 1280×720）已交 judge 复验 PASS。材料见 `V6_1_HOTFIX_REPORT.md`。**当前状态：hotfix 已交付，等待 Owner 确认。**

> **V6.1 FINAL POLISH（2026-09-12 追记）**：Owner 宣布 V6.1 主体验收通过、进入 polish-only。三项已完成：
> 1. `debug_visuals` 开关（默认关；--debug-visuals/F1 开）：命中圈/无敌闪/轨迹/残影/震屏/HUD 指示灯受控；真实 hitbox/VFX/顿帧逻辑不变。
> 2. 12 张满幅方形特效姿势（杨戬 32/33/35、悟空 32/35、唐僧 29/35、沙悟净 32、白龙马 35、小白龙 35、八戒 32/35）已做 bbox 内 alpha 羽化 24px+46px 圆角（`res://art/v6_pose_clean/`，RGB/人物本体未动，程序断言通过），预览器优先加载清理版。
> 3. 阅读尺寸：主预览 280→360px，法相/终结再 ×1.14（只调 scale）。
> 最终视频 `V6_1_FINAL_POLISH.mp4`（H.264 1280×720 39.87s，debug 关，连续录制，0 冻结段），材料见 `V6_1_FINAL_POLISH_REPORT.md`。
> **polish 复验（2026-09-12）**：judge 复验杨戬终结帧（×2.6 满屏演出后本体约 300px）等 5 帧全部 PASS；主截图 PASS。映射复核：`V6_1_MAPPING_UNCHANGED=True`（与补丁包 JSON 哈希一致），`v6_pose/` 288 张未动、`v6_pose_clean/` 仅新增 12 张清理版。**当前状态：等待 Owner 对 polish 的最终验收。**

> **V6.1 进展（2026-09-12 追记）**：Owner 交付精确 Pose 映射补丁，已按 `AI_AGENT_V6.1_精确Pose映射执行指令.md` 完成：
> - V6 原映射已备份（`data/v6_full_keyframes_with_pose.V6.backup.json`），新映射 `data/v6_1_full_keyframes_exact_pose.json`；逐字段校验 **非 pose 字段零差异**（时间/VFX/hitbox/无敌/顿帧/震屏全保留），pose_file 变更 1020/1322（与补丁自带 diff 一致）；1322/1322 全有 pose_file 且指向现有 288 Pose（280 被引用）；0 新美术。
> - 预览器改读 V6.1 数据；修复 `_run_movie` 的 `char_idx` 未同步 bug（曾致第 2 角色起播错库）。
> - 验收视频：`V6_1_SKILL_DEMO.mp4` = H.264 High / **1280×720** / 30fps / 2:53.30 / 5199 帧，全部 83 动作 Movie Maker 固定时间步**连续录制**（0.5s 间隔采样 345 对，冻结段 0），无 GIF。
> - 材料：`V6_1_SKILL_IMPORT_REPORT.md` / `V6_1_GALLERY_SCREENSHOT.png` / `V6_1_SKILL_DEMO.mp4`。
> - **当前状态：等待 Owner 对 V6.1 的视频验收。**

> **V6 裁定（2026-09-12 最新状态）：REAL_POSE_PIPELINE_ACCEPTED / SKILL_POSE_SEMANTICS_NEEDS_REVIEW。**
> V6 技术实现与真实 Pose 切换验收**通过**；技能-Pose 语义（哪个姿势配哪一帧）待 Owner 下一版精确映射补丁复核。
> **冻结/保留（Owner 指令，不得回滚）**：V6 全部实现——288 Pose、1322 keyframes、texture discrete track、VFX/hitbox/invulnerable/hitstop/shake、V6 previewer（res://scenes/skill_preview_v6/ + res://scripts/skill_preview_v6/）、隐藏桌面渲染器（hidden_run.py）。
> **Agent 禁止事项（等待期间）**：不得自行重新映射 Pose；不得猜测哪些 Pose 更适合技能；不得重新生成图片；不得重做 288 Pose。
> **视频提交新规（Owner 指令）**：今后验收视频一律 **MP4（H.264）、≥720p、实际连续播放动作**；禁止"三个时间点截图拼接冒充动画"，GIF 不再作为验收交付物。
> **下一版录制预案（已验证条件）**：用 Godot Movie Maker（`--write-movie`，固定时间步逐帧渲染=真连续）或 30fps 连续抓帧，经 ffmpeg 编码 H.264 MP4。本机 ffmpeg 已确认可用：`C:\Users\54662\AppData\Roaming\Python\Python310\site-packages\imageio_ffmpeg\binaries\ffmpeg-win-x86_64-v7.1.exe`。录制仍在隐藏桌面执行。
> **当前状态：暂停，等待 Owner 下一份精确技能-Pose 映射补丁。**

> **V6 进展（2026-09-12 追记）**：Owner 交付 V6"真实姿势"包后已完成复现（288 张真实姿势 PNG 按关键帧 `pose_file` 离散换装 + V5 程序轨道全套；1322/1322 覆盖；姿势 PNG SHA-256 未修改），材料见 `V6_SKILL_IMPORT_REPORT.md` / `V6_SKILL_COUNTS.json` / `V6_GALLERY_SCREENSHOT.png` / `V6_POSE_CONTACT_SCREENSHOT.png` / `V6_SKILL_DEMO.gif`（PIL 复核 153 帧动画）。渲染全程使用 Windows 隐藏桌面，不干扰 Owner 使用电脑。另发现并修复切角色 Rig 延迟释放导致的轨道失配 bug（V5 GIF 第 2 段起受此影响；V6 已修复并验证）。V4/V5 冻结条款继续有效。

> **V5 进展（2026-09-12 追记）**：Owner 已交付 V5 包，V5 已按 `05_AI_AGENT/AI_AGENT_V5_复现执行指令.md` 完成实现（程序关键帧路线：8 角色 / 83 动作 / 1322 关键帧，基准 PNG 未修改，`V4_FRAME_MAPPING_USED=false`），材料见 `V5_SKILL_IMPORT_REPORT.md` / `V5_SKILL_COUNTS.json` / `V5_GALLERY_SCREENSHOT.png` / `V5_SKILL_DEMO.gif`（GIF 经 PIL 复核为 42 帧动画）。V4 冻结条款继续有效；V4 的 GIF 问题未在 V4 材料上返工，而是由 V5 全新录制替代。

## 最终状态

**TECHNICAL_IMPORT_ACCEPTED / VISUAL_ANIMATION_REJECTED**

- 技术导入：**通过**。8 角色 × 36 帧 = 288 帧全部落位 `res://art/frames/<角色slug>/<动作slug>/`，13 组动画/角色按总表 CSV 帧序建成；Nearest + 无 mipmaps；预览场景 `res://scenes/skill_preview/skill_gallery.tscn` 功能齐全（A/D 切角色、W/S 切动作、J/K/L 播放/暂停/循环，HUD 齐全）。
- 技能动画终验：**不通过**（Owner 视觉/动作验收否决）。具体否决原因以 Owner 反馈为准，Agent 不自行揣测补记。

## Owner 指令（冻结条款，Agent 必须遵守）

1. **停止修改 V4 美术资源**：不重画、不补帧、不重新分配技能、不让任何 AI 生成新图片。
2. 当前 Godot 接入代码与预览器**保留为技术基座**（`scripts/skill_preview/`、`scenes/skill_preview/`、`skill_manifest.json`、SpriteLib 覆盖链不动）。
3. 等待 Owner 提供 **V5 正式技能关键帧包**；V5 到达后按同一技术基座重新落位/导入/录制。

## GIF 核查结论（VIDEO_OR_GIF 暂不标 PASS）

- 本地文件 `SKILL_GALLERY_DEMO.gif` 经核查**确为多帧动画 GIF**：文件头 `GIF89a`，`n_frames=28`，每帧 130ms，640×360，1,751,260 字节（PIL Image.is_animated=True）。
- Owner 验收时收到的"单帧 PNG"判断为**上传/传输环节的格式转换**所致，非本地产物缺陷。
- 按 Owner 指令：**VIDEO_OR_GIF=NOT_ACCEPTED（暂不标记 PASS）**，待 V5 到货后与截图一起重新录制并重新提交验收。

## V4 验收材料归档（仅供参考，视觉验收以 Owner 否决为准）

- 报告：`ART_SKILL_IMPORT_REPORT.md`
- 数量：`ART_SKILL_COUNTS.json`（8/36/288/13/used_original_png_only=true）
- 截图：`SKILL_GALLERY_SCREENSHOT.png`、`SKILL_GALLERY_GRID.png`
- GIF：`SKILL_GALLERY_DEMO.gif`（本地 28 帧动画，未通过终验，待 V5 重录）

## V5 待办（Agent 预备，不提前执行）

1. 收到 V5 包后：解压 → 以其逐帧清单为准重新落位 `res://art/frames/`（替换内容，不动目录结构）→ 复用 `skill_manifest.json` 生成脚本与预览场景。
2. 重录 GIF/截图（实机抓帧，落盘后用 PIL 复核 n_frames≥10 才提交，并附帧数证据）。
3. 重新提交：SKILL_IMPORT_COMPLETED 格式 + 全部验收材料。
