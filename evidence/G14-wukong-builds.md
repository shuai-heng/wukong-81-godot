# G14 · 悟空三条 build（夜间队列）——**PASS 关闭**

## 三路线实现与验证（headless+窗口双模式全绿）

1. **A 三棒重击流**：法天象地（w_giant）在库时第三棒重击半径/伤害路线成长（185+30×lvl / 2.2+0.4×lvl）；
2. **B 破式爆炸流**：破式标记（冲刺/筋斗上标）→ 命中引爆追伤 25%+20%×破式加深（w_pose），w_clone 解锁 AOE 引爆；
3. **C 毫毛分身**：w_72 毫毛分身卡——冲刺留幻相自动攻击（40%+15%×lvl 基础攻击），场上至多 3 具。

## 验证（headless+窗口双模式全绿）

- headless：exit 0，pass=true，27,265 kills，g_count=1，五副本门控 400s 上限截断（baguaFurnace 完成），level 25 有界，零 pageerror
- 窗口：exit 0，pass=true，33,477 kills，g_count=1，screenshot saved
- 三选一结构自检 200 抽 0 违例；存档往返 0 差异；12 章 victory；七英雄全解锁

## 附带交付（同批未提交工作一并入库）

- G12 G 键框架+度厄真言（gong 动作+g_count+全屏净化）
- G13 白龙化龙（dragon_left 10s 形态+移速×1.38+伤害×1.25+蓝鳞视觉）
- P15 小白龙三路线（分层引爆/穿怪CD返还/雷链传播）
- take_damage 诊断收窄（wdMark/dstack/dragonMarkedAlive 字段）

## G14 关闭后

- G 队列下一步：五外传副本剩余四项（dragonStory 等）逐个验证已在本轮 five-trial 队列覆盖；后续按 HANDOFF §5 ①美术对接→②深度机制→③章节铺量
