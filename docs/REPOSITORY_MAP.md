# Godot 仓库整理地图

更新时间：2026-09-13

目标：让任何人或 AI 在 1 分钟内知道“哪里是正式代码、哪里是正式美术、哪里只是历史证据”，并停止继续向根目录堆产物。

## 1. 两个西游仓库怎么分工

### `shuai-heng/wukong-81-trials`

定位：**产品 / 设计事实源**。

负责：唐僧开局与师徒招募顺序、人物外传、神通解锁、能力门禁、八十一难设计、角色产品定位、产品路线与来源层级。

### `shuai-heng/wukong-81-godot`

定位：**当前 Godot 实现仓**。

负责：Godot 代码与场景、正式运行资产、关键帧 / 锚点 / 技能数据、自动测试、美术接入、运行与视觉证据。

原则：设计只维护一个事实源，实现只维护一个主运行仓。

## 2. 当前根目录

整理后的根目录固定为：

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

根目录不再承担“历史版本展览馆”的职责。

## 3. 正式目录职责

| 路径 | 分类 | 说明 |
|---|---|---|
| `project.godot` | 工程入口 | Godot 项目入口 |
| `scenes/` | 运行时 | 正式场景 |
| `scripts/` | 运行时 | 正式 GDScript |
| `data/` | 运行时 | 关键帧、body anchors、章节 / 战斗数据 |
| `art/` | 运行时美术 | 角色、Boss、小怪、姿势、技能美术 |
| `assets/` | 运行时资源 | 通用正式资源 |
| `art_source_exact/` | 美术来源 | 精确源图 / 校验材料 |
| `tests/` | 测试 | smoke、KF probe、回归 |
| `tools/` | 工具 | 生成、转换、诊断、回放 |
| `evidence/` | 证据 | 日志、报告、截图、录像、验收材料 |
| `docs/` | 文档 | Godot 仓结构与实现说明 |
| `README.md` | 顶层入口 | 当前状态 / 如何运行 / 目录入口 |
| `AGENTS.md` | 协作规则 | 人类与 AI 工程代理硬规则 |

## 4. 已完成的历史根目录归档

本轮没有删除历史证据，而是直接复用原 Git blob 改路径；图片、视频、JSON 和报告内容均未重编码。

### 旧美术导入 / 画廊证据

```text
ART_*
SKILL_GALLERY_*
```

已迁至：

```text
evidence/archive/art-pipeline/
```

### V5 历史证据

```text
V5_*
```

已迁至：

```text
evidence/archive/v5/
```

### V6 历史证据

```text
V6_*
```

已迁至：

```text
evidence/archive/v6/
```

注意：这里仅指原根目录证据；`art/v6_pose/`、`art/v6_pose_clean/` 等正式运行资产没有移动。

### V6.1 历史证据

```text
V6_1_*
```

已迁至：

```text
evidence/archive/v6.1/
```

### 诊断脚本

原根目录：

```text
hidden_run.py
hidden_run.ps1
replay_g13.py
```

已迁至：

```text
tools/diagnostics/
```

## 5. art/ 为什么没有一起“大整理”

`art/` 本身已经具备合理分类：

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

这些是运行资产，可能被 `res://`、场景、代码或测试动态引用。为了让根目录“更漂亮”而重命名它们，收益远低于风险，所以本轮刻意不动。

以后只有确实需要重构运行资产时，才按以下流程执行：引用扫描 → 路径修改 → Godot import/parse → smoke/probe → 提交。

## 6. evidence/ 推荐继续演进的结构

根目录已经清理完成；`evidence/` 内部可以后续按需要渐进整理，不要求一次完成：

```text
evidence/
├─ current/               # 当前里程碑必要证据
├─ archive/
│  ├─ art-pipeline/
│  ├─ v5/
│  ├─ v6/
│  └─ v6.1/
├─ milestones/            # G10/G11/G12... 等关闭报告
└─ incidents/             # log flood、冻结、恢复等事故闭环
```

旧的 G10/G11/G12 等日志与报告当前仍保留原位置，后续只有在引用关系核清后再细分，不为“整齐”强行搬动。

## 7. 新产物应该怎么放

不要再生成这种根目录文件：

```text
V6_1_HOTFIX_AFTER_KF8.png
```

改为按任务 / 里程碑保存：

```text
evidence/current/m2-r4/wukong-tangmonk-combat-frame-08.png
```

或：

```text
evidence/milestones/m2-r4/visual-review.md
```

诊断工具统一放：

```text
tools/diagnostics/
```

## 8. 本轮整理完成项

- [x] README 更新到真实 M2 R4 / V6.1 状态；
- [x] 明确 `wukong-81-trials` 与 `wukong-81-godot` 的职责边界；
- [x] 新增 `AGENTS.md`；
- [x] 增加根目录防复发 `.gitignore`；
- [x] `ART_*` / `SKILL_GALLERY_*` 归档；
- [x] `V5_*` 归档；
- [x] `V6_*` 归档；
- [x] `V6_1_*` 归档；
- [x] 根目录诊断脚本归位；
- [x] 正式运行代码、数据、美术路径保持不动。

下一阶段如果继续整理，优先处理 `evidence/` 内部的旧日志分层，而不是动运行资产。
