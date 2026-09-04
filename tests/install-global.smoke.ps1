[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$installer = Join-Path $repositoryRoot 'install-global.ps1'
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('inq-codex-smoke-' + [guid]::NewGuid().ToString('N'))

function Assert-Condition {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

try {
    New-Item -ItemType Directory -Path $testRoot -Force | Out-Null
    $agentRoot = Join-Path $testRoot 'agents'
    New-Item -ItemType Directory -Path $agentRoot -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $testRoot 'config.toml') -Encoding utf8 -NoNewline @"
approval_policy = "never"

[agents]
max_concurrent_threads_per_session = 2
"@
    Set-Content -LiteralPath (Join-Path $agentRoot 'luna-worker-light.toml') -Encoding utf8 -NoNewline 'legacy'
    Set-Content -LiteralPath (Join-Path $agentRoot 'material-scientist.toml') -Encoding utf8 -NoNewline 'legacy'

    & $installer -TargetCodexHome $testRoot -MaxConcurrentThreads 3

    $config = Get-Content -Raw (Join-Path $testRoot 'config.toml')
    Assert-Condition ($config -match 'approval_policy = "never"') 'Existing config was not preserved.'
    Assert-Condition ($config -match 'model = "gpt-5.6-terra"') 'Main model was not installed.'
    Assert-Condition ($config -match 'default_subagent_model = "gpt-5.6-terra"') 'Default subagent model was not installed.'
    Assert-Condition ($config -match 'max_concurrent_threads_per_session = 3') 'Thread count was not merged.'

    foreach ($agent in 'architect', 'planner', 'implementer', 'tester', 'reviewer') {
        Assert-Condition (Test-Path -LiteralPath (Join-Path $agentRoot "$agent.toml") -PathType Leaf) "Missing lifecycle agent: $agent"
    }
    foreach ($retired in 'luna-worker-light', 'luna-worker-medium', 'luna-worker-high', 'material-scientist') {
        Assert-Condition (-not (Test-Path -LiteralPath (Join-Path $agentRoot "$retired.toml") -PathType Leaf)) "Retired agent remains: $retired"
    }
    Assert-Condition (Test-Path -LiteralPath (Join-Path $testRoot 'backups\inq-codex-multi-agents') -PathType Container) 'Expected backup directory was not created.'

    & $installer -TargetCodexHome $testRoot -MaxConcurrentThreads 3
    $trackedText = (Get-ChildItem -LiteralPath $repositoryRoot -Recurse -File -Force |
        Where-Object { $_.FullName -notmatch '\\.git\\' } |
        Get-Content -Raw) -join "`n"
    Assert-Condition ($trackedText -notmatch '(?i)sk-ant-[a-z0-9_-]{12,}') 'Repository appears to contain an Anthropic API key.'

    Write-Host 'Installer smoke test passed.'
}
finally {
    if (Test-Path -LiteralPath $testRoot) {
        Remove-Item -LiteralPath $testRoot -Recurse -Force
    }
}
