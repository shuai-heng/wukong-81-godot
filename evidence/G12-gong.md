# G12 · G 键世界神通框架 + 度厄真言（夜间队列）

## 交付

1. **project.godot**：新增 `gong` 输入动作（physical_keycode 71 = G 键）；
2. **player.gd**：`g_count`/`g_cd_left` 变量、G 键输入分支（冷却 25s）、`_cast_g()` 实现——唐僧度厄真言：全屏净化爆发（30+6×t_nova 伤害全体敌人+击退），自动驾驶（_ai_drive）tang 怒气外周期施放；
3. **main.gd**：冒烟断言接入 `player.g_count >= 1`，结果 JSON 暴露 g_count；
4. 其余英雄的 G 神通（白龙化龙等）按队列后续切片。

## 验证（双模式全绿）

| 模式 | 结果 |
| --- | --- |
| headless（-- --smoke，含五副本队列前期运行） | exit 0，pass=true，**g_count=1**，27,653 kills，零 SCRIPT ERROR |
| 带窗口（--resolution 1280x720） | exit 0，pass=true，**g_count=1**，screenshot=saved |

## 过程修复（本轮引入的损坏，全部当场捕获修复）

1. player.gd 变量合并断裂（`g_cd_left := 0.0var e_cd_left`）；
2. _ai_drive G 块缩进错乱（4tab/3tab/0tab）——上述两处曾导致 player.gd 解析失败（敌人报 take_damage 不存在的根因），修复后 headless exit 0 零脚本错误；
3. main.gd 冒烟断言字面量 `\n` 污染（GDScript 续行断裂）——按字节重建续行块；
4. _cast_g 曾误调不存在的 `_sfx`/`main_ref_flash`——移除（伤害音效由结算统一播放）。

## G12 后续切片（已记入队列）

- 白龙化龙（G 键第二神通）、度厄真言的净化净化层数联动、其余英雄 G 神通逐个补齐。
