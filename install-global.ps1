[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
    [string]$TargetCodexHome = $(
        if (-not [string]::IsNullOrWhiteSpace($env:CODEX_HOME)) {
            $env:CODEX_HOME
        }
        else {
            Join-Path ([Environment]::GetFolderPath('UserProfile')) '.codex'
        }
    ),

    [ValidateRange(1, 64)]
    [int]$MaxConcurrentThreads = 4
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$sourceRoot = $PSScriptRoot
$sourceAgentsFile = Join-Path $sourceRoot 'AGENTS.md'
$sourceAgentsDirectory = Join-Path $sourceRoot '.codex\agents'
$targetRoot = [IO.Path]::GetFullPath($TargetCodexHome)
$targetAgentsFile = Join-Path $targetRoot 'AGENTS.md'
$targetConfigFile = Join-Path $targetRoot 'config.toml'
$targetAgentsDirectory = Join-Path $targetRoot 'agents'
$backupRoot = Join-Path $targetRoot ('backups\inq-codex-multi-agents\' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
$utf8NoBom = New-Object Text.UTF8Encoding($false)
$beginMarker = '<!-- BEGIN inq-codex-multi-agents -->'
$endMarker = '<!-- END inq-codex-multi-agents -->'
$changedFiles = New-Object Collections.Generic.List[string]
$plannedFiles = New-Object Collections.Generic.List[string]

function Assert-SafeTarget {
    param([Parameter(Mandatory = $true)][string]$Path)

    $trimmedPath = $Path.TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
    $trimmedRoot = [IO.Path]::GetPathRoot($Path).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)

    if ([string]::IsNullOrWhiteSpace($trimmedPath) -or $trimmedPath -eq $trimmedRoot) {
        throw "Refusing to use a filesystem root as TargetCodexHome: $Path"
    }
}

function Read-TextFile {
    param([Parameter(Mandatory = $true)][string]$Path)

    [IO.File]::ReadAllText($Path)
}

function Write-TextFile {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Content
    )

    $parent = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    [IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
}

function Backup-ExistingFile {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$RelativePath
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return
    }

    $backupPath = Join-Path $backupRoot $RelativePath
    $backupParent = Split-Path -Parent $backupPath
    if (-not (Test-Path -LiteralPath $backupParent -PathType Container)) {
        New-Item -ItemType Directory -Path $backupParent -Force | Out-Null
    }

    Copy-Item -LiteralPath $Path -Destination $backupPath -Force
}

function Normalize-Newlines {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Content,
        [Parameter(Mandatory = $true)][string]$Newline
    )

    (($Content -replace "`r`n", "`n") -replace "`r", "`n") -replace "`n", $Newline
}

function Get-MergedAgentsGuidance {
    param(
        [Parameter(Mandatory = $true)][string]$SourceContent,
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$ExistingContent
    )

    $newline = if ($ExistingContent.Contains("`r`n")) { "`r`n" } else { "`n" }
    $normalizedSource = (Normalize-Newlines -Content $SourceContent -Newline $newline).Trim()
    $managedBlock = $beginMarker + $newline + $normalizedSource + $newline + $endMarker
    $startIndex = $ExistingContent.IndexOf($beginMarker, [StringComparison]::Ordinal)
    $endIndex = $ExistingContent.IndexOf($endMarker, [StringComparison]::Ordinal)

    if (($startIndex -ge 0) -xor ($endIndex -ge 0)) {
        throw 'AGENTS.md contains only one installation marker. Restore the marker pair or remove the incomplete marker before retrying.'
    }

    if ($startIndex -ge 0) {
        if ($endIndex -lt $startIndex) {
            throw 'AGENTS.md installation markers are out of order.'
        }

        $secondStart = $ExistingContent.IndexOf($beginMarker, $startIndex + $beginMarker.Length, [StringComparison]::Ordinal)
        $secondEnd = $ExistingContent.IndexOf($endMarker, $endIndex + $endMarker.Length, [StringComparison]::Ordinal)
        if ($secondStart -ge 0 -or $secondEnd -ge 0) {
            throw 'AGENTS.md contains multiple managed marker blocks.'
        }

        $afterBlock = $endIndex + $endMarker.Length
        return $ExistingContent.Substring(0, $startIndex) + $managedBlock + $ExistingContent.Substring($afterBlock)
    }

    if ([string]::IsNullOrWhiteSpace($ExistingContent)) {
        return $managedBlock + $newline
    }

    return $ExistingContent.TrimEnd() + $newline + $newline + $managedBlock + $newline
}

function Get-MergedConfig {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$ExistingContent,
        [Parameter(Mandatory = $true)][int]$ThreadCount
    )

    $newline = if ($ExistingContent.Contains("`r`n")) { "`r`n" } else { "`n" }
    $content = (Normalize-Newlines -Content $ExistingContent -Newline "`n")
    $sectionPattern = '(?m)^[ \t]*\[agents\][ \t]*(?:#.*)?$'
    $sectionMatches = [regex]::Matches($content, $sectionPattern)

    if ($sectionMatches.Count -gt 1) {
        throw 'config.toml contains more than one [agents] table.'
    }

    $settingLine = "max_concurrent_threads_per_session = $ThreadCount"

    if ($sectionMatches.Count -eq 0) {
        $content = $content.TrimEnd()
        if ($content.Length -gt 0) {
            $content += "`n`n"
        }
        $content += "[agents]`n$settingLine`n"
        return Normalize-Newlines -Content $content -Newline $newline
    }

    $section = $sectionMatches[0]
    $sectionBodyStart = $section.Index + $section.Length
    $remainingContent = $content.Substring($sectionBodyStart)
    $nextSection = [regex]::Match($remainingContent, '(?m)^[ \t]*\[[^\r\n]+\][ \t]*(?:#.*)?$')
    $sectionBodyEnd = if ($nextSection.Success) { $sectionBodyStart + $nextSection.Index } else { $content.Length }
    $sectionBody = $content.Substring($sectionBodyStart, $sectionBodyEnd - $sectionBodyStart)
    $settingPattern = '(?m)^([ \t]*)max_concurrent_threads_per_session[ \t]*=.*?([ \t]+#.*)?$'
    $settingMatches = [regex]::Matches($sectionBody, $settingPattern)

    if ($settingMatches.Count -gt 1) {
        throw 'The [agents] table contains duplicate max_concurrent_threads_per_session keys.'
    }

    if ($settingMatches.Count -eq 1) {
        $setting = $settingMatches[0]
        $comment = $setting.Groups[2].Value
        $replacement = $setting.Groups[1].Value + $settingLine + $comment
        $absoluteSettingIndex = $sectionBodyStart + $setting.Index
        $content = $content.Remove($absoluteSettingIndex, $setting.Length).Insert($absoluteSettingIndex, $replacement)
    }
    else {
        $content = $content.Insert($sectionBodyStart, "`n$settingLine")
    }

    Normalize-Newlines -Content $content -Newline $newline
}

Assert-SafeTarget -Path $targetRoot

if (-not (Test-Path -LiteralPath $sourceAgentsFile -PathType Leaf)) {
    throw "Source AGENTS.md was not found: $sourceAgentsFile"
}
if (-not (Test-Path -LiteralPath $sourceAgentsDirectory -PathType Container)) {
    throw "Source agents directory was not found: $sourceAgentsDirectory"
}

$sourceAgentFiles = @(Get-ChildItem -LiteralPath $sourceAgentsDirectory -Filter '*.toml' -File | Sort-Object Name)
if ($sourceAgentFiles.Count -eq 0) {
    throw "No custom agent TOML files were found in: $sourceAgentsDirectory"
}

$sourceGuidance = Read-TextFile -Path $sourceAgentsFile
$existingGuidance = if (Test-Path -LiteralPath $targetAgentsFile -PathType Leaf) {
    Read-TextFile -Path $targetAgentsFile
}
else {
    ''
}
$mergedGuidance = Get-MergedAgentsGuidance -SourceContent $sourceGuidance -ExistingContent $existingGuidance

if ($mergedGuidance -cne $existingGuidance) {
    $plannedFiles.Add($targetAgentsFile)
    if ($PSCmdlet.ShouldProcess($targetAgentsFile, 'Merge global Codex guidance')) {
        Backup-ExistingFile -Path $targetAgentsFile -RelativePath 'AGENTS.md'
        Write-TextFile -Path $targetAgentsFile -Content $mergedGuidance
        $changedFiles.Add($targetAgentsFile)
    }
}

$existingConfig = if (Test-Path -LiteralPath $targetConfigFile -PathType Leaf) {
    Read-TextFile -Path $targetConfigFile
}
else {
    ''
}
$mergedConfig = Get-MergedConfig -ExistingContent $existingConfig -ThreadCount $MaxConcurrentThreads

if ($mergedConfig -cne $existingConfig) {
    $plannedFiles.Add($targetConfigFile)
    if ($PSCmdlet.ShouldProcess($targetConfigFile, 'Merge global multi-agent settings')) {
        Backup-ExistingFile -Path $targetConfigFile -RelativePath 'config.toml'
        Write-TextFile -Path $targetConfigFile -Content $mergedConfig
        $changedFiles.Add($targetConfigFile)
    }
}

foreach ($sourceAgent in $sourceAgentFiles) {
    $targetAgent = Join-Path $targetAgentsDirectory $sourceAgent.Name
    $needsCopy = -not (Test-Path -LiteralPath $targetAgent -PathType Leaf)
    if (-not $needsCopy) {
        $needsCopy = (Get-FileHash -LiteralPath $sourceAgent.FullName -Algorithm SHA256).Hash -cne (Get-FileHash -LiteralPath $targetAgent -Algorithm SHA256).Hash
    }

    if ($needsCopy) {
        $plannedFiles.Add($targetAgent)
        if ($PSCmdlet.ShouldProcess($targetAgent, 'Install custom Codex agent')) {
            Backup-ExistingFile -Path $targetAgent -RelativePath (Join-Path 'agents' $sourceAgent.Name)
            if (-not (Test-Path -LiteralPath $targetAgentsDirectory -PathType Container)) {
                New-Item -ItemType Directory -Path $targetAgentsDirectory -Force | Out-Null
            }
            Copy-Item -LiteralPath $sourceAgent.FullName -Destination $targetAgent -Force
            $changedFiles.Add($targetAgent)
        }
    }
}

Write-Host "Codex home: $targetRoot"
if ($changedFiles.Count -eq 0) {
    if ($plannedFiles.Count -gt 0) {
        Write-Host "Planned $($plannedFiles.Count) file change(s); no files were written."
    }
    else {
        Write-Host 'No file changes were required.'
    }
}
else {
    Write-Host "Updated $($changedFiles.Count) file(s)."
    Write-Host "Backups of replaced files (when applicable): $backupRoot"
}

$overrideFile = Join-Path $targetRoot 'AGENTS.override.md'
if (Test-Path -LiteralPath $overrideFile -PathType Leaf) {
    Write-Warning "AGENTS.override.md exists and takes precedence over AGENTS.md: $overrideFile"
}

Write-Host 'Start a new Codex session to load the updated global configuration.'
