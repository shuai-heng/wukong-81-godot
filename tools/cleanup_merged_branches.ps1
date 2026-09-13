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
if (-not $repoRoot) { throw 'Run this script inside the wukong-81-godot Git repository.' }
Set-Location $repoRoot

$remoteUrl = (& git remote get-url origin).Trim()
if ($remoteUrl -notmatch 'wukong-81-godot') {
    throw "Unexpected origin for this script: $remoteUrl"
}

Write-Host '== Fetching remote ==' -ForegroundColor Cyan
Run-Git fetch origin --prune

$protected = @(
    'main',
    'task/pixel-complete'
)

$knownMerged = @(
    'chore/repo-cleanup-20260913',
    'chore/archive-root-evidence-20260913'
)

$protectedSet = @{}
foreach ($name in $protected) { $protectedSet[$name] = $true }
$knownMergedSet = @{}
foreach ($name in $knownMerged) { $knownMergedSet[$name] = $true }

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
        Write-Warning 'GitHub CLI merged-PR query failed; using Git ancestry and known-merged list.'
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
    else { throw "Unable to determine merge status for branch: $name" }

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
Write-Host "Merged branches eligible for deletion: $($deleteMerged.Count)" -ForegroundColor Green
$deleteMerged | Format-Table Branch, MergeEvidence, LastCommit -AutoSize

Write-Host "Protected or active branches: $($kept.Count)" -ForegroundColor Yellow
$kept | Sort-Object Branch | Format-Table Branch, MergedIntoMain, LastCommit -AutoSize

Write-Host "Stale unmerged branches older than $StaleDays days: $($staleUnmerged.Count)" -ForegroundColor Magenta
$staleUnmerged | Format-Table Branch, LastCommit, Sha -AutoSize

if (-not $Apply) {
    Write-Host ''
    Write-Host 'DRY RUN only. No branches were deleted.' -ForegroundColor Cyan
    Write-Host '.\tools\cleanup_merged_branches.ps1 -Apply'
    Write-Host 'Optional archive-and-delete mode for stale unmerged branches:'
    Write-Host '.\tools\cleanup_merged_branches.ps1 -Apply -ArchiveUnmerged -StaleDays 30'
    exit 0
}

foreach ($row in $deleteMerged) {
    Write-Host "Deleting merged branch: $($row.Branch) [$($row.MergeEvidence)]" -ForegroundColor Green
    Run-Git push origin --delete $row.Branch
}

if ($ArchiveUnmerged) {
    foreach ($row in $staleUnmerged) {
        $safeName = $row.Branch -replace '[^A-Za-z0-9._/-]', '-'
        $tag = "archive/branch-$(Get-Date -Format yyyyMMdd)/$safeName"
        & git rev-parse -q --verify "refs/tags/$tag" 2>$null
        if ($LASTEXITCODE -ne 0) {
            Run-Git tag -a $tag $row.Sha -m "Archive stale branch $($row.Branch) before deletion"
            Run-Git push origin "refs/tags/$tag"
        }
        Write-Host "Archived and deleting stale branch: $($row.Branch) -> $tag" -ForegroundColor Magenta
        Run-Git push origin --delete $row.Branch
    }
}

Write-Host ''
Write-Host 'Branch cleanup completed.' -ForegroundColor Green
