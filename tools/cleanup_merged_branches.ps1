[CmdletBinding()]
param(
    [switch]$Apply,
    [switch]$ArchiveUnmerged,
    [int]$StaleDays = 30
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Run-Git {
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Args)
    & git @Args
    if ($LASTEXITCODE -ne 0) {
        throw "git $($Args -join ' ') failed with exit code $LASTEXITCODE"
    }
}

$repoRoot = (& git rev-parse --show-toplevel 2>$null).Trim()
if (-not $repoRoot) { throw '请在 wukong-81-godot 的本地 Git 仓库中运行。' }
Set-Location $repoRoot

$remoteUrl = (& git remote get-url origin).Trim()
if ($remoteUrl -notmatch 'wukong-81-godot') {
    throw "当前 origin 不是 wukong-81-godot：$remoteUrl"
}

Write-Host '== 刷新远端 ==' -ForegroundColor Cyan
Run-Git fetch origin --prune

$protected = @(
    'main',
    'task/pixel-complete'
)

# 这些分支已由本次仓库整理 PR 明确合并进 main；即使采用 squash merge，仍可安全删除。
$knownMerged = @(
    'chore/repo-cleanup-20260913',
    'chore/archive-root-evidence-20260913'
)

$protectedSet = @{}
foreach ($name in $protected) { $protectedSet[$name] = $true }
$knownMergedSet = @{}
foreach ($name in $knownMerged) { $knownMergedSet[$name] = $true }

# 如果本机装有并登录 GitHub CLI，同时读取 merged PR 的 head branch，兼容 squash/rebase merge。
$mergedPrHeads = @{}
$gh = Get-Command gh -ErrorAction SilentlyContinue
if ($gh) {
    try {
        $prJson = & gh pr list --repo shuai-heng/wukong-81-godot --state merged --limit 500 --json headRefName 2>$null
        if ($LASTEXITCODE -eq 0 -and $prJson) {
            foreach ($pr in ($prJson | ConvertFrom-Json)) {
                if ($pr.headRefName) { $mergedPrHeads[$pr.headRefName] = $true }
            }
        }
    } catch {
        Write-Warning 'GitHub CLI merged-PR 查询失败；继续使用 Git ancestry + knownMerged 安全名单。'
    }
}

$rows = @()
$rawRefs = & git for-each-ref '--format=%(refname:strip=3)|%(objectname)|%(committerdate:unix)' refs/remotes/origin
foreach ($line in $rawRefs) {
    if (-not $line) { continue }
    $parts = $line -split '\|'
    if ($parts.Count -lt 3) { continue }
    $name = $parts[0]
    if ($name -eq 'HEAD' -or $name -eq 'main') { continue }
    $sha = $parts[1]
    $unix = [int64]$parts[2]
    $date = [DateTimeOffset]::FromUnixTimeSeconds($unix).LocalDateTime

    & git merge-base --is-ancestor "origin/$name" origin/main 2>$null
    $code = $LASTEXITCODE
    if ($code -eq 0) { $ancestorMerged = $true }
    elseif ($code -eq 1) { $ancestorMerged = $false }
    else { throw "无法判断分支 $name 是否已合并。" }

    $merged = $ancestorMerged -or $knownMergedSet.ContainsKey($name) -or $mergedPrHeads.ContainsKey($name)
    $reason = if ($ancestorMerged) { 'git-ancestor' } elseif ($knownMergedSet.ContainsKey($name)) { 'known-merged-pr' } elseif ($mergedPrHeads.ContainsKey($name)) { 'github-merged-pr' } else { '' }

    $rows += [pscustomobject]@{
        Branch = $name
        Sha = $sha
        LastCommit = $date
        MergedIntoMain = $merged
        MergeEvidence = $reason
        Protected = $protectedSet.ContainsKey($name)
    }
}

$deleteMerged = @($rows | Where-Object { $_.MergedIntoMain -and -not $_.Protected } | Sort-Object Branch)
$cutoff = (Get-Date).AddDays(-$StaleDays)
$staleUnmerged = @($rows | Where-Object { -not $_.MergedIntoMain -and -not $_.Protected -and $_.LastCommit -lt $cutoff } | Sort-Object LastCommit)
$kept = @($rows | Where-Object { $_.Protected -or (-not $_.MergedIntoMain -and $_.LastCommit -ge $cutoff) })

Write-Host ''
Write-Host "已合并、可安全删除：$($deleteMerged.Count)" -ForegroundColor Green
$deleteMerged | Format-Table Branch, MergeEvidence, LastCommit -AutoSize

Write-Host "受保护/仍活跃：$($kept.Count)" -ForegroundColor Yellow
$kept | Sort-Object Branch | Format-Table Branch, MergedIntoMain, LastCommit -AutoSize

Write-Host "超过 $StaleDays 天但未合并：$($staleUnmerged.Count)" -ForegroundColor Magenta
$staleUnmerged | Format-Table Branch, LastCommit, Sha -AutoSize

if (-not $Apply) {
    Write-Host ''
    Write-Host '当前是 DRY RUN，没有删除任何分支。确认结果后执行：' -ForegroundColor Cyan
    Write-Host '.\tools\cleanup_merged_branches.ps1 -Apply'
    Write-Host '若未来还要清理长期未合并分支，可先归档为 tag 再删除：'
    Write-Host '.\tools\cleanup_merged_branches.ps1 -Apply -ArchiveUnmerged -StaleDays 30'
    exit 0
}

foreach ($row in $deleteMerged) {
    Write-Host "删除已合并分支：$($row.Branch) [$($row.MergeEvidence)]" -ForegroundColor Green
    Run-Git push origin --delete $row.Branch
}

if ($ArchiveUnmerged) {
    foreach ($row in $staleUnmerged) {
        $tag = "archive/branch-$(Get-Date -Format yyyyMMdd)/$($row.Branch)"
        & git rev-parse -q --verify "refs/tags/$tag" 2>$null
        if ($LASTEXITCODE -ne 0) {
            Run-Git tag -a $tag $row.Sha -m "Archive stale branch $($row.Branch) before deletion"
            Run-Git push origin "refs/tags/$tag"
        }
        Write-Host "已归档并删除未合并旧分支：$($row.Branch) -> $tag" -ForegroundColor Magenta
        Run-Git push origin --delete $row.Branch
    }
}

Write-Host ''
Write-Host '分支清理完成。' -ForegroundColor Green
