# M2-R5｜西游技能动画总控制规范 · Godot Vertical Slice

本文件只描述 Godot 实现边界，不复制产品总纲。产品方向仍以 `shuai-heng/wukong-81-trials` 为事实源。

## 本轮目标

把当前 V6.1 “姿势关键帧会播放”继续升级为：

`角色身份 → 人物关键帧 → 身体/武器锚点 → 起手/蓄力 → 释放 → world-space 技能 → contact → impact → 地图反馈 → recovery`

本轮只做一近一远 Vertical Slice：

- 唐僧：远程施法/弹幕；验证 `palm` 锚点、同一动作时钟、projectile 脱手 world-space、远程走位可读性。
- 孙悟空：近中距离武器战；沿用真实 `staff_tip` 棍端轨迹、挥击弧、砸地真实落点与地面反馈。

不得以此轮为理由批量修改所有英雄。

## 硬边界

1. 不改伤害、CD、无敌、碰撞体、升级与平衡数值。
2. 不新增第二套技能时钟；视觉层读取现有 `kf_action` / `kf_t` / `KeyframeLib.release_time()`。
3. 不使用 `player.position + 固定偏移` 伪造技能锚点。
4. 唐僧普通攻击的施法视觉使用 `KeyframeLib.body_anchor_world(..., "palm")`。
5. 唐僧 `ring` projectile 在脱手前绑定真实 palm 世界坐标，脱手后继续使用现有 `main.fx_shots` world-space 生命周期。
6. 悟空棍势继续由 `staff_tip` 实际历史位置采样，不用人物中心假弧线。
7. 法相不贴巨大完整佛像/法身插画；本轮用当前 V6.1 `form` 姿势生成低透明度法相投影与人物专属几何形成过程，碰撞不放大。
8. 唐僧主色固定佛光金/象牙白；悟空固定赤金/金黄；颜色不能替代动作与轨迹差异。
9. VFX 保持克制：平A小、技能中、大招大但有形成过程；不得盖住人物/敌人。
10. 所有新增运行证据落 `evidence/`，不得堆根目录。

## 当前实现

### `scripts/visual_choreography.gd`

Autoload bootstrap。只负责把视觉 rig 挂到现有 runtime Player，不拥有战斗状态。

### `scripts/visual_choreography_rig.gd`

只支持 `tang` / `wukong`：

- 唐僧 `atk_combo`：使用现有 `kf_t` 与 `release_time` 驱动 palm 小法印形成/释放；
- 唐僧新生成的 `ring` shot：在仍未脱手的首帧改绑真实 `palm` 世界坐标，随后仍由现有 `fx_shots` 自己飞行；
- 走位：从当前姿势 `body_center` 读取动势位置，只画极少量方向线；
- 法相：复制当前 V6.1 姿势作为低透明法相投影，按人物身份采用不同形成几何；不改碰撞/数值；
- 悟空已有 `staff_tip` 棍势/砸地地图反馈保持原逻辑，不重复制造第二条攻击轨迹。

## 验收门禁

### 无特效测试

关闭/忽略新增 visual rig 时，V6.1 人物动作本身仍必须能表达动作语义。

### 无人物测试

唐僧 projectile 必须能读出：来源 → 飞行 → contact → impact；悟空 swing 必须能读出真实棍端弧线/落点。

### 换角色测试

唐僧掌前法印 + 脱手弹幕不能直接无违和套给悟空；悟空 `staff_tip` 棍端轨迹不能直接套给唐僧。

### 暂停帧测试

至少检查：release 前、release、travel、contact/impact、recovery；任一帧都应能解释当前发生什么。

### Godot 运行门禁

必须至少执行：

- Godot 4.7.x import / parse；
- `--headless --path . -- --smoke`；
- 关键帧/锚点 probe；
- 唐僧/悟空短录像或 GIF 视觉检查。

未真正执行的项目必须明确标记 `NOT_EXECUTED`，不得写 PASS。
