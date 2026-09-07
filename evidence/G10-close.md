# G10 关闭 · 冒烟静默崩修复 + 五外传副本全验证（夜间队列）

## 根因与修复链（三轮闭环）

1. **复现与定性**（v1-diag 轮）：所谓"静默崩"= 性能死亡螺旋挂起——通天+八卦炉叠加时敌人峰值 201，6 倍时标下帧时间爆炸；外部超时杀进程后表现为"静默退出"。修复：敌人上限 90 + 单 tick ≤16。
2. **窗口缺陷**：victory 后自动驾驶开启 60s 八卦炉，断言窗口 72s 就关——改为等待副本完成（上限 150s→后随五副本验证扩展为 400s/全五副本）。
3. **升级曲线根因**（本轮）：Godot 版 exp_next 线性（5+level×3）与 web 版几何（×1.33）偏离——fangcun 双倍经验下 kills 6965→105989 退化循环后冻结。修复：`exp_next = int(exp_next * 1.33)` 对齐 web；草稿积压上限 3（防草稿风暴）。

## 最终验证（双模式全绿，同轮）

| 模式 | 结果 |
| --- | --- |
| headless（-- --smoke --trial-queue=五副本） | **exit 0，pass=true**：五副本全部完成（dragonStory/fangcun/underworld/heavenHavoc/baguaFurnace），25,929 kills、level 25 有界、elapsed 343.6s < 400s 上限、零 pageerror |
| 带窗口（--resolution 1280x720 + 同队列） | **exit 0，pass=true**，screenshot=saved |

## G10 关闭标准核对

- ✅ 双模式冒烟全绿（headless + 窗口截图）
- ✅ 五外传副本逐个验证通过（dragonStory/fangcun/underworld/heavenHavoc/baguaFurnace 各 60s 完成）
- 冻结根因已修（几何曲线+草稿上限+敌人上限+音效节流+帧时间仪表化留档）

## G10 关闭后 G 队列顺序（按 HANDOFF 第五节）

1. ①美术对接准备（英雄/Boss 正式 sprite 替换接口与 fallback 链）；
2. ②深度机制迁移（G 键世界神通：度厄真言/化龙/天河倒卷；破式叠层完整还原；白龙化龙）；
3. ③更多章节 Boss（CHAPTER_CFG 铺量：狮驼岭/比丘国/无底洞/凤仙郡/玉华州/金平府/天竺/铜台府/凌云渡等）。
