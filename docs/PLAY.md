# 大圣火线：八十一难 · 像素西行录

Windows 单机像素动作游戏。唐僧独自启程，在五行山、鹰愁涧、高老庄、流沙河收服四位伙伴；进入人物外传习得神通，沿西行路线打通后续关卡，最后取经归来。

本分支承接 Godot `c3639bfbbe13330b9c617202781d8728a83c6398`，玩法依据主纲仓库 `shuai-heng/wukong-81-trials` 的 `ead437c513b73097a63fed3f619eeb3d0d1a22a4`。项目负责人在 2026-09-08 要求完成游戏并确认像素风。原 Godot / 美术仓库与 E 盘日志联接没有改动。

## 游戏内容

- 7 名可操作人物：唐僧、悟空、小白龙、八戒、沙悟净、哪吒、杨戬；独立像素形象和普攻、Q/E/G、法相、终结效果。
- 36 处主线地点、81 段西行事件、10 个人物外传，含取经与归途结局。81 是本作的关卡事件编排，非逐项照录原著八十一难目录。
- 神通所有权与人物招募分别保存；幻化、破幻、御水、破风、火阵等需要对应人物。
- 28 种敌人图像、13 种场景配色与环境布置、三阶段首领、红色前摇预警、护送、净化、迷雾、机关与元素危险区。
- 三选一成长、连击法相、命中停顿、击退、闪白、震屏、浮字；22 个原创合成音效和 4 首原创循环配乐。
- 标题、暂停、路线、队伍、设置、失败重试、重游、结局、章内存档与损坏备份恢复。

## 运行与操作

完整 Windows 包位于工作区 `../release/`，双击 `大圣火线.exe`，与同名 `.pck` 放在一起。也可运行 `启动游戏.vbs`，它明确将存档和日志写入游戏旁的 `userdata/`。首次启动选择「踏上取经路」。

源码运行：Godot 4.7.2 打开 `project.godot`，或 `Godot --path .`。不要再使用旧版 `--smoke` 入口。

| 操作 | 按键 |
| --- | --- |
| 移动 / 自动普攻 | WASD 或方向键 / 靠近敌人自动攻击 |
| 招式 / 外传神通 | Q、E / G |
| 悟空已学双神通时主动变化 | Shift + G；变化关卡中 G 自动选择变化 |
| 短暂无敌冲刺 | Space |
| 法相内满灵力终结 | R |
| 收服力竭首领 / 揭印 | 靠近后 F |
| 换人 / 队伍 / 路线 | T / Tab / M |
| 暂停 / 升级选择 | Esc / 1、2、3 或鼠标 |
| 指定招式方向 | 按住鼠标右键，再施放招式 |

金色标记是当前目标。目标周围击退妖潮，护送时靠近灵灯并保护它；完成目标后迎战首领。缺神通时路线界面会说明获取外传。每 15 秒、关卡结算、返回标题和关窗时保存。存档独立于旧游戏，不会默认解锁所有人物。

## 本地验证

在仓库根目录运行，日志路径请指向 F/E 盘。没有 GitHub Actions。

```powershell
Godot --path . --log-file F:/Projects/xiyou-81/wukong-godot/evidence/pixel-regression-gpu.log --script res://tests/verify_pixel.gd -- --verification
Godot --headless --path . --log-file F:/Projects/xiyou-81/wukong-godot/evidence/pixel-playthrough.log --script res://tests/playthrough_pixel.gd -- --verification
Godot --path . --log-file F:/Projects/xiyou-81/wukong-godot/evidence/pixel-performance.log --script res://tests/performance_pixel.gd -- --verification
```

`evidence/pixel-regression.json`：132 项针对性检查。`pixel-playthrough.json`：正常伤害和冷却的 46 次章节/外传通关；不会注入秒杀伤害或跳过目标。`pixel-package.json`：实际 PCK 里的菜单点击、移动、施法、音频与保存。`pixel-performance.json`：70 敌人真实显卡负载采样。截图另见同目录。

详见实现与验证记录 `docs/COMPLETION.md`。这是本地完整旅程候选包；自动通关不等同于人工对美术、平衡与打击感的最终接受。
