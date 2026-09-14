# 唐僧 R8｜Release 窗口与干净前推掌

目标：继续收紧唐僧远程动作，不再让 POSE_24 在整个动作中长时间僵住，也不允许任何烘焙月牙/烟云重新进入人物层。

## 核心调整

- 正式 Release 图片仍来自 V6 原 POSE_24 的人物本体，但必须使用 `art/v7_clean/tang_sanzang/tang_sanzang__POSE_24__CAST_CLEAN.png` 清理版。
- normal/Q/G/R 的 POSE_24 只出现在真正 Release 附近的短窗口；其余阶段用 POSE_02 / POSE_03 / POSE_13 连接动作。
- Release 前：合掌/袖手前引；Release 瞬间：右掌前推；Release 后：短暂回到袖手/合掌，再收回持杖。
- Release 关键帧窗口由同一 `KeyframeLib.kf_t` 与 `kf_release_t` 推导，不建立第二套独立技能时钟。
- projectile 仍从当前可见 POSE 的 palm 产生，脱手后进入 world-space。
- 人物整图 crossfade 继续禁止。
- 不改伤害、CD、护盾、净化、法相时长、终结伤害上限等平衡数值。

## 验收

1. 平A：POSE_24 不得长时间停留，必须只在出手瞬间出现。
2. Q：八角法印在右掌前推时脱手，不能人物已经收掌后才生成。
3. G/R：连续弹幕可以持前推掌，但持势只覆盖实际多弹 release 段；释放结束立即进入 recovery。
4. 关闭所有程序 VFX 后，人物仍能看出“聚势 → 前推释放 → 收招”。
5. 任意暂停在 windup / release / travel / impact / recovery，都能解释当前发生的动作。
