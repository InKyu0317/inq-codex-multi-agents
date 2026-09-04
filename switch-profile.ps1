[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
    [ValidateSet('openai', 'claude')]
    [string]$Profile,

    [switch]$Status,

    [string]$TargetCodexHome = $(
        if (-not [string]::IsNullOrWhiteSpace($env:CODEX_HOME)) {
            $env:CODEX_HOME
        }
        else {
            Join-Path ([Environment]::GetFolderPath('UserProfile')) '.codex'
        }
    )
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$roles = @('architect', 'planner', 'implementer', 'tester', 'reviewer')
$utf8NoBom = New-Object Text.UTF8Encoding($false)
$targetRoot = [IO.Path]::GetFullPath($TargetCodexHome)
$profilesRoot = Join-Path $PSScriptRoot 'profiles'
$configPath = Join-Path $targetRoot 'config.toml'
$agentsRoot = Join-Path $targetRoot 'agents'

function Assert-SafeTarget {
    param([Parameter(Mandatory = $true)][string]$Path)

    $trimmedPath = $Path.TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
    $trimmedRoot = [IO.Path]::GetPathRoot($Path).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
    if ([string]::IsNullOrWhiteSpace($trimmedPath) -or $trimmedPath -eq $trimmedRoot) {
        throw "Refusing to use a filesystem root as TargetCodexHome: $Path"
    }
}

function Normalize-Newlines {
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Content, [Parameter(Mandatory = $true)][string]$Newline)
    (($Content -replace "`r`n", "`n") -replace "`r", "`n") -replace "`n", $Newline
}

function Get-RootAndTables {
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Content)
    $firstTable = [regex]::Match($Content, '(?m)^[ \t]*\[[^\r\n]+\][ \t]*(?:#.*)?$')
    if ($firstTable.Success) {
        return @($Content.Substring(0, $firstTable.Index), $Content.Substring($firstTable.Index))
    }
    return @($Content, '')
}

function Set-TomlSetting {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Content,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Value
    )

    $pattern = "(?m)^([ \t]*)$([regex]::Escape($Name))[ \t]*=.*?([ \t]+#.*)?$"
    $settingMatches = [regex]::Matches($Content, $pattern)
    if ($settingMatches.Count -gt 1) { throw "Duplicate $Name settings found." }
    $settingLine = "$Name = $Value"
    if ($settingMatches.Count -eq 1) {
        $match = $settingMatches[0]
        return $Content.Remove($match.Index, $match.Length).Insert($match.Index, $match.Groups[1].Value + $settingLine + $match.Groups[2].Value)
    }
    if ($Content.Length -gt 0 -and -not $Content.EndsWith("`n")) { $Content += "`n" }
    return $Content + "$settingLine`n"
}

function Set-TomlTableSetting {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Content,
        [Parameter(Mandatory = $true)][string]$Table,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Value
    )

    $tablePattern = "(?m)^[ \t]*\[$([regex]::Escape($Table))\][ \t]*(?:#.*)?$"
    $tableMatches = [regex]::Matches($Content, $tablePattern)
    if ($tableMatches.Count -gt 1) { throw "config.toml contains more than one [$Table] table." }
    if ($tableMatches.Count -eq 0) {
        $Content = $Content.TrimEnd()
        if ($Content.Length -gt 0) { $Content += "`n`n" }
        return $Content + "[$Table]`n$Name = $Value`n"
    }

    $tableMatch = ([regex]::new($tablePattern)).Match($Content)
    $bodyStart = $tableMatch.Index + $tableMatch.Length
    $remaining = $Content.Substring($bodyStart)
    $nextTable = [regex]::Match($remaining, '(?m)^[ \t]*\[[^\r\n]+\][ \t]*(?:#.*)?$')
    $bodyEnd = if ($nextTable.Success) { $bodyStart + $nextTable.Index } else { $Content.Length }
    $body = $Content.Substring($bodyStart, $bodyEnd - $bodyStart)
    $updatedBody = Set-TomlSetting -Content $body -Name $Name -Value $Value
    return $Content.Remove($bodyStart, $body.Length).Insert($bodyStart, $updatedBody)
}

function Get-TomlStringSetting {
    param([Parameter(Mandatory = $true)][string]$Content, [Parameter(Mandatory = $true)][string]$Name)
    $pattern = '(?m)^\s*' + [regex]::Escape($Name) + '\s*=\s*"([^"]+)"\s*(?:#.*)?$'
    $settingMatches = [regex]::Matches($Content, $pattern)
    if ($settingMatches.Count -ne 1) { return $null }
    return $settingMatches[0].Groups[1].Value
}

function Read-Profile {
    param([Parameter(Mandatory = $true)][string]$Name)
    $path = Join-Path $profilesRoot "$Name.json"
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Profile definition was not found: $path" }
    $definition = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
    if ($definition.name -ne $Name -or [string]::IsNullOrWhiteSpace($definition.main.model) -or [string]::IsNullOrWhiteSpace($definition.main.reasoning_effort)) {
        throw "Profile definition is incomplete: $path"
    }
    foreach ($role in $roles) {
        $entry = $definition.roles.PSObject.Properties[$role].Value
        if ($null -eq $entry -or [string]::IsNullOrWhiteSpace($entry.model) -or [string]::IsNullOrWhiteSpace($entry.reasoning_effort)) {
            throw "Profile $Name is missing a complete $role role definition."
        }
    }
    return $definition
}

function Get-ProfileMatch {
    param([Parameter(Mandatory = $true)][string]$ConfigContent)
    foreach ($name in @('openai', 'claude')) {
        $definition = Read-Profile -Name $name
        if ((Get-TomlStringSetting -Content $ConfigContent -Name 'model') -ne $definition.main.model) { continue }
        $matches = $true
        foreach ($role in $roles) {
            $path = Join-Path $agentsRoot "$role.toml"
            if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { $matches = $false; break }
            $content = Get-Content -LiteralPath $path -Raw
            if ((Get-TomlStringSetting -Content $content -Name 'model') -ne $definition.roles.PSObject.Properties[$role].Value.model) { $matches = $false; break }
        }
        if ($matches) { return $name }
    }
    return 'custom-or-mixed'
}

function Write-TextFile {
    param([Parameter(Mandatory = $true)][string]$Path, [Parameter(Mandatory = $true)][string]$Content)
    [IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
}

Assert-SafeTarget -Path $targetRoot
if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) { throw "Codex config was not found: $configPath" }
if (-not (Test-Path -LiteralPath $profilesRoot -PathType Container)) { throw "Profiles directory was not found: $profilesRoot" }

if ($Status) {
    $currentConfig = Get-Content -LiteralPath $configPath -Raw
    Write-Output "Active profile: $(Get-ProfileMatch -ConfigContent $currentConfig)"
    exit 0
}

if ([string]::IsNullOrWhiteSpace($Profile)) { throw 'Specify -Profile openai or -Profile claude, or use -Status.' }
$definition = Read-Profile -Name $Profile
$staged = [ordered]@{}
$originalConfig = Get-Content -LiteralPath $configPath -Raw
$newline = if ($originalConfig.Contains("`r`n")) { "`r`n" } else { "`n" }
$parts = Get-RootAndTables -Content (Normalize-Newlines -Content $originalConfig -Newline "`n")
$root = Set-TomlSetting -Content $parts[0] -Name 'model' -Value ('"' + $definition.main.model + '"')
$root = Set-TomlSetting -Content $root -Name 'model_reasoning_effort' -Value ('"' + $definition.main.reasoning_effort + '"')
$updatedConfig = $root + $parts[1]
$updatedConfig = Set-TomlTableSetting -Content $updatedConfig -Table 'agents' -Name 'default_subagent_model' -Value ('"' + $definition.default_subagent.model + '"')
$updatedConfig = Set-TomlTableSetting -Content $updatedConfig -Table 'agents' -Name 'default_subagent_reasoning_effort' -Value ('"' + $definition.default_subagent.reasoning_effort + '"')
$staged[$configPath] = Normalize-Newlines -Content $updatedConfig -Newline $newline

foreach ($role in $roles) {
    $path = Join-Path $agentsRoot "$role.toml"
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Lifecycle agent file was not found: $path" }
    $existing = Get-Content -LiteralPath $path -Raw
    $agentNewline = if ($existing.Contains("`r`n")) { "`r`n" } else { "`n" }
    $updated = Set-TomlSetting -Content (Normalize-Newlines -Content $existing -Newline "`n") -Name 'model' -Value ('"' + $definition.roles.PSObject.Properties[$role].Value.model + '"')
    $updated = Set-TomlSetting -Content $updated -Name 'model_reasoning_effort' -Value ('"' + $definition.roles.PSObject.Properties[$role].Value.reasoning_effort + '"')
    $staged[$path] = Normalize-Newlines -Content $updated -Newline $agentNewline
}

$backupRoot = Join-Path $targetRoot ('backups\inq-codex-model-profiles\' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
$activeProfilePath = Join-Path $profilesRoot 'active-profile.json'
$marker = [ordered]@{ name = $definition.name; switched_at = (Get-Date).ToUniversalTime().ToString('o') } | ConvertTo-Json

if (-not $PSCmdlet.ShouldProcess($targetRoot, "Switch the Main and lifecycle agents to the $Profile profile")) { exit 0 }
New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
$written = New-Object Collections.Generic.List[string]
try {
    foreach ($entry in $staged.GetEnumerator()) {
        $relative = $entry.Key.Substring($targetRoot.Length).TrimStart([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
        $backupPath = Join-Path $backupRoot $relative
        $backupParent = Split-Path -Parent $backupPath
        New-Item -ItemType Directory -Path $backupParent -Force | Out-Null
        Copy-Item -LiteralPath $entry.Key -Destination $backupPath -Force
    }
    if (Test-Path -LiteralPath $activeProfilePath -PathType Leaf) {
        $activeProfileBackup = Join-Path $backupRoot 'profiles\active-profile.json'
        New-Item -ItemType Directory -Path (Split-Path -Parent $activeProfileBackup) -Force | Out-Null
        Copy-Item -LiteralPath $activeProfilePath -Destination $activeProfileBackup -Force
    }

    foreach ($entry in $staged.GetEnumerator()) {
        $temporary = "$($entry.Key).profile-switch-$PID.tmp"
        Write-TextFile -Path $temporary -Content $entry.Value
        Move-Item -LiteralPath $temporary -Destination $entry.Key -Force
        $written.Add($entry.Key)
    }
    Write-TextFile -Path $activeProfilePath -Content ($marker + "`n")
    $written.Add($activeProfilePath)
}
catch {
    foreach ($path in $written) {
        $relative = $path.Substring($targetRoot.Length).TrimStart([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
        $backupPath = Join-Path $backupRoot $relative
        if (Test-Path -LiteralPath $backupPath -PathType Leaf) { Copy-Item -LiteralPath $backupPath -Destination $path -Force }
    }
    throw
}

Write-Host "Applied profile: $Profile"
Write-Host "Backups: $backupRoot"
Write-Host 'Start a new Codex session before creating new subagents.'
