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
$sourceProfilesDirectory = Join-Path $sourceRoot 'profiles'
$sourceProfileSwitcher = Join-Path $sourceRoot 'switch-profile.ps1'
$targetRoot = [IO.Path]::GetFullPath($TargetCodexHome)
$targetAgentsFile = Join-Path $targetRoot 'AGENTS.md'
$targetConfigFile = Join-Path $targetRoot 'config.toml'
$targetAgentsDirectory = Join-Path $targetRoot 'agents'
$targetProfilesDirectory = Join-Path $targetRoot 'profiles'
$targetProfileSwitcher = Join-Path $targetRoot 'switch-profile.ps1'
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
    $firstTable = [regex]::Match($content, '(?m)^[ \t]*\[[^\r\n]+\][ \t]*(?:#.*)?$')
    $rootContent = if ($firstTable.Success) { $content.Substring(0, $firstTable.Index) } else { $content }
    $tableContent = if ($firstTable.Success) { $content.Substring($firstTable.Index) } else { '' }

    foreach ($setting in @(
        @{ Name = 'model'; Value = '"gpt-5.6-terra"' },
        @{ Name = 'model_reasoning_effort'; Value = '"high"' }
    )) {
        $settingLine = "$($setting.Name) = $($setting.Value)"
        $settingPattern = "(?m)^([ \t]*)$([regex]::Escape($setting.Name))[ \t]*=.*?([ \t]+#.*)?$"
        $settingMatches = [regex]::Matches($rootContent, $settingPattern)

        if ($settingMatches.Count -gt 1) {
            throw "config.toml contains duplicate top-level $($setting.Name) keys."
        }

        if ($settingMatches.Count -eq 1) {
            $existingSetting = $settingMatches[0]
            $replacement = $existingSetting.Groups[1].Value + $settingLine + $existingSetting.Groups[2].Value
            $rootContent = $rootContent.Remove($existingSetting.Index, $existingSetting.Length).Insert($existingSetting.Index, $replacement)
        }
        else {
            if ($rootContent.Length -gt 0 -and -not $rootContent.EndsWith("`n")) {
                $rootContent += "`n"
            }
            $rootContent += "$settingLine`n"
        }
    }

    $content = $rootContent + $tableContent
    $sectionPattern = '(?m)^[ \t]*\[agents\][ \t]*(?:#.*)?$'
    $sectionMatches = [regex]::Matches($content, $sectionPattern)

    if ($sectionMatches.Count -gt 1) {
        throw 'config.toml contains more than one [agents] table.'
    }

    $agentSettings = @(
        @{ Name = 'max_concurrent_threads_per_session'; Value = "$ThreadCount" },
        @{ Name = 'default_subagent_model'; Value = '"gpt-5.6-terra"' },
        @{ Name = 'default_subagent_reasoning_effort'; Value = '"medium"' }
    )

    if ($sectionMatches.Count -eq 0) {
        $content = $content.TrimEnd()
        if ($content.Length -gt 0) {
            $content += "`n`n"
        }
        $content += "[agents]`n"
        foreach ($setting in $agentSettings) {
            $content += "$($setting.Name) = $($setting.Value)`n"
        }
        return Normalize-Newlines -Content $content -Newline $newline
    }

    foreach ($agentSetting in $agentSettings) {
        $section = [regex]::Match($content, $sectionPattern)
        $sectionBodyStart = $section.Index + $section.Length
        $remainingContent = $content.Substring($sectionBodyStart)
        $nextSection = [regex]::Match($remainingContent, '(?m)^[ \t]*\[[^\r\n]+\][ \t]*(?:#.*)?$')
        $sectionBodyEnd = if ($nextSection.Success) { $sectionBodyStart + $nextSection.Index } else { $content.Length }
        $sectionBody = $content.Substring($sectionBodyStart, $sectionBodyEnd - $sectionBodyStart)
        $settingLine = "$($agentSetting.Name) = $($agentSetting.Value)"
        $settingPattern = "(?m)^([ \t]*)$([regex]::Escape($agentSetting.Name))[ \t]*=.*?([ \t]+#.*)?$"
        $settingMatches = [regex]::Matches($sectionBody, $settingPattern)

        if ($settingMatches.Count -gt 1) {
            throw "The [agents] table contains duplicate $($agentSetting.Name) keys."
        }

        if ($settingMatches.Count -eq 1) {
            $setting = $settingMatches[0]
            $replacement = $setting.Groups[1].Value + $settingLine + $setting.Groups[2].Value
            $absoluteSettingIndex = $sectionBodyStart + $setting.Index
            $content = $content.Remove($absoluteSettingIndex, $setting.Length).Insert($absoluteSettingIndex, $replacement)
        }
        else {
            $content = $content.Insert($sectionBodyStart, "`n$settingLine")
        }
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
if (-not (Test-Path -LiteralPath $sourceProfilesDirectory -PathType Container)) {
    throw "Source profiles directory was not found: $sourceProfilesDirectory"
}
if (-not (Test-Path -LiteralPath $sourceProfileSwitcher -PathType Leaf)) {
    throw "Source profile switcher was not found: $sourceProfileSwitcher"
}

$sourceAgentFiles = @(Get-ChildItem -LiteralPath $sourceAgentsDirectory -Filter '*.toml' -File | Sort-Object Name)
if ($sourceAgentFiles.Count -eq 0) {
    throw "No custom agent TOML files were found in: $sourceAgentsDirectory"
}
$sourceProfileFiles = @(Get-ChildItem -LiteralPath $sourceProfilesDirectory -Filter '*.json' -File | Sort-Object Name)
if ($sourceProfileFiles.Count -eq 0) {
    throw "No profile definitions were found in: $sourceProfilesDirectory"
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

foreach ($sourceProfile in $sourceProfileFiles) {
    $targetProfile = Join-Path $targetProfilesDirectory $sourceProfile.Name
    $needsCopy = -not (Test-Path -LiteralPath $targetProfile -PathType Leaf)
    if (-not $needsCopy) {
        $needsCopy = (Get-FileHash -LiteralPath $sourceProfile.FullName -Algorithm SHA256).Hash -cne (Get-FileHash -LiteralPath $targetProfile -Algorithm SHA256).Hash
    }

    if ($needsCopy) {
        $plannedFiles.Add($targetProfile)
        if ($PSCmdlet.ShouldProcess($targetProfile, 'Install Codex model profile')) {
            Backup-ExistingFile -Path $targetProfile -RelativePath (Join-Path 'profiles' $sourceProfile.Name)
            if (-not (Test-Path -LiteralPath $targetProfilesDirectory -PathType Container)) {
                New-Item -ItemType Directory -Path $targetProfilesDirectory -Force | Out-Null
            }
            Copy-Item -LiteralPath $sourceProfile.FullName -Destination $targetProfile -Force
            $changedFiles.Add($targetProfile)
        }
    }
}

$switcherNeedsCopy = -not (Test-Path -LiteralPath $targetProfileSwitcher -PathType Leaf)
if (-not $switcherNeedsCopy) {
    $switcherNeedsCopy = (Get-FileHash -LiteralPath $sourceProfileSwitcher -Algorithm SHA256).Hash -cne (Get-FileHash -LiteralPath $targetProfileSwitcher -Algorithm SHA256).Hash
}
if ($switcherNeedsCopy) {
    $plannedFiles.Add($targetProfileSwitcher)
    if ($PSCmdlet.ShouldProcess($targetProfileSwitcher, 'Install Codex model profile switcher')) {
        Backup-ExistingFile -Path $targetProfileSwitcher -RelativePath 'switch-profile.ps1'
        Copy-Item -LiteralPath $sourceProfileSwitcher -Destination $targetProfileSwitcher -Force
        $changedFiles.Add($targetProfileSwitcher)
    }
}

foreach ($retiredAgentName in @(
    'advisor.toml',
    'researcher.toml',
    'frontend-expert.toml',
    'python-expert.toml',
    'csharp-expert.toml',
    'rust-expert.toml',
    'glass-scientist.toml',
    'luna-worker-light.toml',
    'luna-worker-medium.toml',
    'luna-worker-high.toml',
    'material-scientist.toml'
)) {
    $retiredAgent = Join-Path $targetAgentsDirectory $retiredAgentName
    if (Test-Path -LiteralPath $retiredAgent -PathType Leaf) {
        $plannedFiles.Add($retiredAgent)
        if ($PSCmdlet.ShouldProcess($retiredAgent, 'Retire legacy Codex agent')) {
            Backup-ExistingFile -Path $retiredAgent -RelativePath (Join-Path 'agents' $retiredAgentName)
            Remove-Item -LiteralPath $retiredAgent -Force
            $changedFiles.Add($retiredAgent)
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
