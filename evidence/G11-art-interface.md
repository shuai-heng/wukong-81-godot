# G11 · 美术对接准备——sprite 替换接口与 fallback 链（夜间队列）

## 交付（scripts/sprite_lib.gd）

1. **覆盖链**：`heroes/<kind>.png` → `enemies/<kind>.png` → 像素图集回退——正式 sprite 美术管线（wukong-81-art，A03+）产出后按文件名放入对应目录即自动生效，零代码改动；
2. **加载缓存**：ResourceLoader.exists 探测 + load 缓存（_art_cache），缺失回退图集帧构建（build_frames 原逻辑不变）；
3. 覆盖时以整图单帧构建 idle/run/atk/hurt 四动画（6fps，atk/hurt 不循环）——正式 sprite 多帧图集约定后续与美术管线对齐后可扩展；
4. main 节点加入 "main_ctl" 组（后续测试钩子入口）。

## 验证（真实运行三轮）

| 场景 | 结果 |
| --- | --- |
| 放入 stand-in（assets/art/heroes/tang.png，48×96 缩放自 evidence/smoke.png + --import） | ✅ `[ART] override sprite: tang` 多次打印，窗口冒烟 exit 0 pass=true（400s 上限截断为接口验证运行） |
| 截图 | ✅ evidence/g11/tang-sprite-override.png（替换后的 tang 战斗画面） |
| 移除 stand-in 后回退图集 | ✅ 冒烟 exit 0 pass=true、override 0 次、零 SCRIPT ERROR |
| 新增 PNG 后 --import 生效 | ✅（规矩④的资源导入坑实测确认） |

## 边界与约定（如实）

- 覆盖链当前为**整图单帧**——正式 sprite 的多帧图集布局（列数/帧数/fps 元数据）待与美术管线 A03+ 对齐后扩展 build_frames 的 regions 解析；
- enemies/bosses 同一接口（enemies/<kind>.png），bosses 目录骨架已建；
- stand-in PNG 已从工作树移除（不入库）。

## 产物

- scripts/sprite_lib.gd（覆盖链）
- evidence/g11/tang-sprite-override.png、g11-override-run*.log、g11-fallback-run.log
