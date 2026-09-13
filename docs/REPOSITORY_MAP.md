# Godot 仓库整理地图

更新时间：2026-09-13

目标：让任何人或 AI 在 1 分钟内知道“哪里是正式代码、哪里是正式美术、哪里只是历史证据”，并停止继续向根目录堆产物。

## 1. 两个西游仓库怎么分工

### `shuai-heng/wukong-81-trials`

定位：**产品 / 设计事实源**。

负责：

- 唐僧开局与师徒招募顺序；
- 人物外传；
- 神通解锁与能力门禁；
- 八十一难设计；
- 角色产品定位；
- 产品路线、设计红线与来源层级。

### `shuai-heng/wukong-81-godot`

定位：**当前 Godot 实现仓**。

负责：

- Godot 代码与场景；
- 正式运行资产；
- 关键帧、锚点与技能数据；
- 自动测试；
- Godot 侧美术接入；
- 运行与视觉证据。

原则：设计只维护一个事实源，实现只维护一个主运行仓。

## 2. 当前正式目录

| 路径 | 分类 | 处理结论 | 说明 |
|---|---|---|---|
| `project.godot` | 工程入口 | 保留根目录 | Godot 项目入口 |
| `scenes/` | 运行时 | 保留 | 正式场景 |
| `scripts/` | 运行时 | 保留 | 正式 GDScript |
| `data/` | 运行时 | 保留 | 关键帧、body anchors 等正式数据 |
| `art/` | 运行时美术 | 保留 | 已按角色 / Boss / 小怪 / 姿势 / 技能分层 |
| `assets/` | 运行时资源 | 保留 | 通用正式资源 |
| `art_source_exact/` | 美术来源 | 保留 | 精确源图 / 校验材料，不与运行资产混合 |
| `tests/` | 测试 | 保留 | smoke、KF probe 等 |
| `tools/` | 工具 | 保留并继续细分 | 后续一次性诊断脚本归到这里 |
| `evidence/` | 证据 | 保留并继续细分 | 日志、报告、截图、录像统一入口 |
| `docs/` | 文档 | 保留 | Godot 仓本地说明 |
| `README.md` | 入口文档 | 保留根目录 | 当前状态 / 如何运行 / 仓库地图 |
| `AGENTS.md` | 协作规则 | 保留根目录 | AI 与工程代理硬规则 |

## 3. 根目录历史杂物分类

以下文件目前之所以“看起来很乱”，主要不是因为它们没有价值，而是因为 **放错位置**。

### A. 旧美术导入 / 画廊证据

匹配：

- `ART_*`
- `SKILL_GALLERY_*`

建议目标：

```text
evidence/archive/art-pipeline/
```

包括截图、GIF、导入数量 JSON、导入报告、视觉复核说明。

### B. V5 历史视觉与技能证据

匹配：

- `V5_*`

建议目标：

```text
evidence/archive/v5/
```

这些不应再作为当前状态入口，但应保留用于追溯。

### C. V6 历史视觉与技能证据

匹配：

- `V6_*`

建议目标：

```text
evidence/archive/v6/
```

注意：这里指根目录的证据文件，不包括 `art/v6_pose/` 等正式运行资产。

### D. V6.1 历史截图 / 录像 / hotfix 报告

匹配：

- `V6_1_*`

建议目标：

```text
evidence/archive/v6.1/
```

包括最终演示视频、关键帧证据、hotfix 前后截图、报告等。

### E. 根目录诊断脚本

当前可见：

- `hidden_run.py`
- `hidden_run.ps1`
- `replay_g13.py`

建议目标：

```text
tools/diagnostics/
```

迁移前先扫描文档 / 命令 / 脚本是否仍引用旧路径。

## 4. evidence/ 后续结构

当前 `evidence/` 已经是正确方向，但内部仍混有多个时期的日志和报告。以后建议统一：

```text
evidence/
├─ current/               # 当前里程碑必要证据
├─ archive/
│  ├─ art-pipeline/
│  ├─ v5/
│  ├─ v6/
│  └─ v6.1/
├─ milestones/            # G10/G11/G12... 等任务关闭报告
└─ incidents/             # log flood、冻结、恢复等事故闭环
```

不要求一次性把所有旧证据搬完；按独立 commit 分批迁移即可。

## 5. art/ 当前结构判断

`art/` 本身不是主要问题，现有分类已经具备长期维护价值：

```text
art/
├─ bosses/
├─ characters/
├─ enemies/
├─ frames/
├─ skillsheets/
├─ v5_base/
├─ v6_pose/
└─ v6_pose_clean/
```

因此本次整理 **不建议为了“看起来统一”重命名或大搬 art/**。它属于运行资产，风险远高于收益。

后续若要建立更完整的 Boss / 小怪 / 主角美术生产线，可以在保持已有运行路径兼容的前提下逐步演进，而不是先大改目录。

## 6. 本轮整理边界

### Phase 1：安全治理

- 更新 README；
- 新增 AGENTS；
- 新增本仓库地图；
- 明确双仓职责；
- 明确以后禁止根目录继续堆产物。

该阶段不移动运行代码、不移动正式美术、不删除历史文件。

### Phase 2：历史产物归档

单独提交完成：

1. 根目录 `ART_*` / `SKILL_GALLERY_*` → `evidence/archive/art-pipeline/`；
2. 根目录 `V5_*` → `evidence/archive/v5/`；
3. 根目录 `V6_*` → `evidence/archive/v6/`；
4. 根目录 `V6_1_*` → `evidence/archive/v6.1/`；
5. 更新任何旧路径引用。

这一步只搬历史证据，原则上不改游戏逻辑。

### Phase 3：工具归位

- `hidden_run.py/.ps1`
- `replay_g13.py`

迁到 `tools/diagnostics/`，同时修复引用并执行对应验证。

### Phase 4：可选的证据瘦身

对于大体积 MP4 / GIF：

- 若仍是验收必需，可继续保留或改为 Release artifact；
- 若只是阶段性录屏且已有结构化报告 / 截图替代，则后续评估是否从源码主树移除；
- 不在未确认前直接删除。

## 7. 整理完成后的理想根目录

目标不是“文件越少越好”，而是入口一眼能懂：

```text
.gitignore
AGENTS.md
README.md
project.godot
art/
art_source_exact/
assets/
data/
docs/
evidence/
scenes/
scripts/
tests/
tools/
```

看到根目录就应该知道项目怎么运行，而不是先穿过几十个历史截图和视频。

## 8. 新产物命名建议

不要再用只有版本号但没有任务语义的根目录文件名，例如：

```text
V6_1_HOTFIX_AFTER_KF8.png
```

改为按任务目录保存：

```text
evidence/current/m2-r4/wukong-tangmonk-combat-frame-08.png
```

或：

```text
evidence/milestones/m2-r4/visual-review.md
```

这样版本演进后仍能知道文件为什么存在。
