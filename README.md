# 大圣火线：八十一难 · Godot 版

像素风竖切（Godot 4.7），与 web 主线（`wukong-81-trials`）并行。

## 运行

```
"D:\edge download\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe" --path "F:\Zcode projects\西游\wukong-godot"
```

## 冒烟自检（自动验证）

```
# 逻辑冒烟（无窗口）
Godot_v4.7.2-stable_win64_console.exe --headless --path . -- --smoke
# 带截图冒烟（窗口闪现 ~2s，输出 evidence/smoke.png）
Godot_v4.7.2-stable_win64_console.exe --path . -- --smoke
```

断言：自动驾驶 10s 游戏时间内 kills>=5 且 atk_count>=10；结果落盘 `evidence/smoke-result.json`。

## 切片计划

- G00 ✅ 工程骨架 / 像素图集接入 / 移动·自动攻击·冲刺·刷怪·经验成长 / 冒烟自检
- G01 三选一升级（卡牌结构对齐 web 版 U-001 分类系统）
- G02 Q/E 技能 + 龙痕类机制迁移评估
- G03 Boss（五行山）+ 收服循环
- G04 存档（对齐 web 版 S-001 存档矩阵教训）
