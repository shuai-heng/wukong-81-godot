# G10 · 冒烟 72s+ 静默崩修复（夜间队列 · 插队完成主体）

## 根因链（两轮诊断闭环）

1. **真身定性**：所谓"静默崩"= **性能死亡螺旋挂起**——通天章节 + 八卦炉外传叠加时敌人峰值 201（2.5 倍冒烟密度），6 倍时标下逐 hit 顿帧/音效/伤害数字使帧时间爆炸，进程假死（无输出无退出），外部超时杀掉后表现为"静默退出"。复现证据：v1-diag-log.txt（t=50 后冻结，4 分钟墙钟零推进）。
2. **窗口缺陷（连带）**：victory 后自动驾驶开启 60s 八卦炉外传，而断言窗口 elapsed≥72 就评估——副本需 ~85-95s 完成，永远差 15-20s，`trial_done` 恒空必败。

## 修复（scripts/main.gd）

1. **敌人上限 90**（_spawn_tick 触发即跳过刷怪）+ 单 tick 生成上限 16——封顶死亡螺旋的敌人规模；enemy_cap_hits 诊断计数；
2. **断言窗口等待副本完成**：`victory and trial_done.is_empty() and elapsed<150` 时延后评估（上限 150s 游戏时间）；
3. **帧时间仪表化**：smoke 模式逐帧记录实际 max delta，每 10s 游戏时间打印；
4. **音效节流**：hit/pickup 80ms 去重（高密度下的音效播放churn）。

## 验证（双模式全绿）

| 模式 | 结果 |
| --- | --- |
| headless（-- --smoke） | **exit 0，pass=true**：冻结点（t=40-70，enemies 封顶 96，maxframe 0.015-0.041s 无螺旋）顺利穿过；t=80 八卦炉完成；12 章+victory+七英雄+save ok 全绿；5117 kills |
| 带窗口（--resolution 1280x720） | **exit 0，pass=true**，evidence/smoke.png 已产出；4784 kills |

（修复前对照：v1-diag 轮在同一冻结点 t=50-59 挂死 4 分钟零推进。）

## 剩余（G10 完整关闭前）

- 五外传副本逐个验证：本轮自动驾驶仅覆盖 **baguaFurnace ✅**；其余四项（dragonStory/fangcun/underworld/heavenHavoc）需 startTrial 测试钩子逐个驱动验证——机制同构（time 60s + mods），预期风险低，下一轮第一任务。
- 良性报错备案：headless 下 `Parameter "t" is null`（字体主题）与 `_finish_smoke` 截图 get_image（if img: 已处理）。
