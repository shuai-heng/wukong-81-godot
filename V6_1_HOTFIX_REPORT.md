# V6.1 最终 Hotfix 报告 —— 悟空终结技《齐天镇岳·金箍贯地》Pose/VFX 边界清理

时间：2026-09-12 · 范围：仅 sun_wukong 终结技使用的 4 张姿势（31/33/34/36）；其他角色与 288 Pose 库未动

## 校验与评审结论

- POSE_MAPPING_UNCHANGED=true（V6.1 JSON 与补丁包哈希一致）
- REGENERATED_ART=0（仅 alpha 外圈羽化；4 张 RGB 通道逐像素不变、alpha 变更全部限定在羽化带内——程序断言通过）
- judge 评审：BEFORE 确认硬切边/矩形块可见 → AFTER 首版发现人物上身处羽化带内被淡化（FAIL）→ 收窄羽化带并提高 floor 重调后 **AFTER PASS**（边界消除、人物本体清晰明亮）

## 修复项（对应 Owner 指认）

| 指认问题 | 定位 | 处理 |
| --- | --- | --- |
| 左侧岩石明显垂直硬切边 | POSE_31（锁定全场）左缘、POSE_36（落地收棍）左缘：源图册相邻格切片导致岩石/旋涡被垂直切断 | 左缘定向 alpha 羽化 48–56px（切边侧 floor=0 完全淡出） |
| 悟空头部/背后矩形特效块边界 | POSE_34（巨棒伸长/触地白闪，KF7–18）顶部：金棍光柱与红巾被图幅上缘平切，形成头部/背后矩形块边界 | 顶缘定向 alpha 羽化 40px（floor=0.3，光柱/披风自然淡出画面） |
| 连带 | POSE_33（跃入云层）右缘、POSE_34 底部岩石、POSE_36 右缘同类硬切一并柔化 | 同上（floor 0.3–0.5） |

## 手段与红线

- 仅修改**外围 alpha**（定向边缘羽化，smoothstep 渐变）；**RGB 通道全图逐像素不变**（程序断言 4/4 通过）——人物、武器、特效颜色像素零修改。
- Pose mapping 未动：`data/v6_1_full_keyframes_exact_pose.json` 与补丁包哈希一致。
- 无新增图片：羽化版写入 `res://art/v6_pose_clean/` 对应文件（POSE_35 沿用此前清理版），预览器加载逻辑不变。

## 材料

- BEFORE：`V6_1_HOTFIX_BEFORE_KF8.png`（KF8/28 巨棒伸长：顶部矩形块+左缘切边可见）、`V6_1_HOTFIX_BEFORE_KF2.png`（KF2/28 锁定全场：左缘岩石切边）
- AFTER：`V6_1_HOTFIX_AFTER_KF8.png`（同帧位，边界已清除、人物保亮）、`V6_1_HOTFIX_AFTER_KF2.png`
- 视频：`V6_1_HOTFIX_FINISH.mp4` —— H.264 / 1280×720 / 30fps / **6.90 秒**，终结技连续真实播放（idle 起手 1.2s + 完整一演 + 收尾），debug_visuals 关
