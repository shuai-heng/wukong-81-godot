# V6.1 精确 Pose 映射补丁报告

生成时间：2026-09-12
依据：`04_AI_AGENT/AI_AGENT_V6.1_精确Pose映射执行指令.md`
输入：`西游V6.1_83技能精确Pose映射补丁.zip`（10 个条目）
执行方式：全程 Windows 隐藏桌面离屏渲染（含视频逐帧录制），主桌面零干扰。

## 1. 映射替换（只改 pose 字段）

- 备份：`res://data/v6_full_keyframes_with_pose.V6.backup.json`（V6 原始映射已备份）
- 新数据：`res://data/v6_1_full_keyframes_exact_pose.json`（来自 `02_完整关键帧替换/`，未改动）
- 预览器 `skill_gallery_v6.gd` 已改读 V6.1 JSON；Texture Track 保持 `UPDATE_DISCRETE`

**逐字段校验**（V6 vs V6.1，1322 对关键帧）：

| 校验 | 结果 |
| --- | --- |
| 角色/动作/关键帧主键 | 1322 对全部一致 |
| 非 pose 字段（time_ms、body、rotation、scale、vfx、hitbox、invulnerable、camera_shake、hitstop、trail、afterimage） | **零差异** → V6_TIMING_VFX_PRESERVED=true |
| pose_id / pose_file 变更 | **1020 / 1322** 处更换（302 处保持），与补丁自带 `V6_to_V6_1_keyframe_diff.csv` 一致 |
| V6.1 每关键帧 pose_file 存在性 | 1322/1322 全部指向现有 288 张姿势 PNG，无新增/缺失 |
| 被引用姿势 | 280/288（Owner 映射决定，Agent 未改动） |
| REGENERATED_ART | 0（无任何图片重新生成；288 Pose 库原样复用，SHA-256 未动） |
| patch_meta | mapping_method=manual_character_specific_action_semantic_mapping（Owner 人工语义映射） |

## 2. 验收视频（MP4，不再交付 GIF）

| 项 | 值 |
| --- | --- |
| 文件 | `V6_1_SKILL_DEMO.mp4`（47,598,155 字节） |
| 编码 | H.264（High profile），yuv420p |
| 分辨率 | **1280×720** |
| 时长 / 帧数 | 2:53.30 / **5199 帧 @30fps** |
| 内容 | 全部 **83 个动作**按角色顺序**连续真实播放**（含每动作顿帧/震屏/命中演出），非时间点拼接 |
| 连续性证据 | 0.5s 间隔采样 345 对相邻帧，平均像素差 2.2–15.7，**冻结段 0**；Movie Maker 固定时间步逐帧渲染 |
| 内容证据 | `V6_1_VIDEO_EVIDENCE_SHEET.jpg`：抽帧核实（唐僧 杖尾点地 · 八戒 左回耙+命中环 · 杨戬 神犬穿心/天眼+哮天犬），姿势与动作注记语义一致 |

录制流程：Godot `--write-movie`（AVI/MJPEG 临时文件，已删除）→ ffmpeg 转码 H.264 MP4。过程中发现并修复 `_run_movie` 的 `char_idx` 未随角色同步的 bug（曾导致第 2 个角色起播错动作库；已修复并全量重录）。注意：顿帧计时器按 30fps 取整会累计约 13s 的播放漂移，属录制期真实播放时长，不影响动作完整性。

## 3. 预览与截图

- 主截图：`V6_1_GALLERY_SCREENSHOT.png` —— 悟空 法天象地 KF12/22"金箍棒通天"，V6.1 新映射下为竖棍砸地姿势（与 V6 旧映射的横扫姿势不同，映射变更肉眼可证）
- 预览键位不变：A/D 切角色 · W/S 切动作 · J 播放 · K 暂停 · L 循环；HUD 含 source_tier/解锁来源/KF 进度/姿势注记/状态灯

## 4. 红线自查

- 未重新生成图片、未重新裁 Pose、未重做技术基座 ✓
- 未自行修改 Owner 的映射（1020 处变更与补丁 diff 文件一致）✓
- 时长/VFX/hitbox/无敌/顿帧/震屏全部保留 ✓
- `V5_EXPANSION` 等标记原样保留 ✓
- 未交付 GIF（按新规仅 MP4）✓
