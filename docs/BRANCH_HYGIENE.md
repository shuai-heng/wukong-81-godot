# Branch Hygiene｜分支生命周期规则

本规则用于防止 `wukong-81-godot` 再次积累大量一次性分支。

## 长期保留的 branch

正常情况下只长期保留：

- `main`：唯一稳定主线；
- 当前确实仍在开发、且 main 尚未吸收的唯一任务 branch；
- 项目负责人明确要求保留的特殊实验线。

当前 `task/pixel-complete` 仍包含 main 没有的独立实现，因此暂时保护，不按历史垃圾删除。

## 一个任务只允许一个 branch

同一个任务的返工继续使用原 branch。

禁止创建：

```text
task/foo-r1
task/foo-r2
task/foo-final
task/foo-final2
```

R2/R3/R4 写进 commit / evidence，不通过新增 branch 表示。

## 合并后立即清 branch

任务已经进入 `main` 后：

1. 保留 commit / PR / evidence；
2. 删除远端 branch；
3. 不把 branch 当历史档案。

历史快照优先使用 tag。

## 未合并历史 branch

长期不用但仍有独立提交时：

1. 建立 `archive/branch-YYYYMMDD/<old-branch>` annotated tag；
2. 推送 tag；
3. 再删除旧 branch。

## AI / AutoPilot 规则

所有工程代理：

- 一个 bounded task 只使用一个 branch；
- 返工继续原 branch；
- PR / 集成完成后 branch cleanup 属于 closeout；
- 不新建 backup/temp/final2 一类 branch；
- 不根据历史 branch 名猜当前事实，实际状态以 `main`、README、AGENTS 与当前任务文件为准。

## 清理工具

默认 DRY RUN：

```powershell
.\tools\cleanup_merged_branches.ps1
```

删除确认已合并的 branch：

```powershell
.\tools\cleanup_merged_branches.ps1 -Apply
```

长期未合并分支需要进一步瘦身时：

```powershell
.\tools\cleanup_merged_branches.ps1 -Apply -ArchiveUnmerged -StaleDays 30
```
