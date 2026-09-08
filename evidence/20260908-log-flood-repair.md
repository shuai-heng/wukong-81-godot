# 2026-09-08 玩家脚本与失控日志修复

根因：player.gd 自动驾驶 G 分支缩进错误导致解析失败；dragon_left/dragon_cd_left 状态未声明。主场景动态挂载失败后仍继续运行，逐帧调用空 CharacterBody2D 的 hp、magnet_r、take_damage，导致日志膨胀。

修复：合并自动驾驶 G 分支，补齐化龙状态及技能分支，使用现有 g_cd_left 倒计时并阻止冷却内重放；化龙结束和英雄切换恢复视觉及状态；唐僧 G 改为使用实际存在的敌人血量和待删除状态；主场景预加载并实例化玩家脚本，使依赖解析失败时不继续生成空玩家；无窗口冒烟跳过截图纹理读取。

验证：本机 Godot 4.7.2。独立副本 application/config/name=CDriveRepairValidation-20260908，与真实游戏存档隔离。
- 专项回归：PLAYER_REGRESSION failures=0，覆盖生命值、伤害、拾取接口、真实敌人 G 技能伤害、冷却、化龙数值/结束/切换。
- 现有战斗冒烟：exit 0，pass=true，模拟400秒，12章，35193击杀，日志零 ERROR / SCRIPT ERROR。
- 该冒烟仅完成 baguaFurnace 外传，不能据此宣称五外传全部验证。
- git diff --check 通过。未运行可视窗口验收。

复现专项测试：复制 scripts/assets/scenes/project.godot 至独立目录，修改副本项目名为上述验证名称，运行 Godot --headless --path <副本> --import，再运行 --headless --path <副本> --script <本项目 tests/player_regression.gd 的绝对路径>。测试包含项目名保护，不应直接在真实存档环境运行 --smoke。

日志副本存放于本 evidence 目录，原始代码备份在 C:\Users\54662\Documents\ChatGPT\清理c盘。已有 E 盘日志映射保持有效。
