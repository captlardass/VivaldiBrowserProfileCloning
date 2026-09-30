<#
.SYNOPSIS
    Copies Vivaldi settings (the "Preferences" file) from a chosen template
    profile to other Vivaldi profiles, keeping each target's own name and avatar.

.DESCRIPTION
    - Lists all Vivaldi profiles and asks which one to copy settings FROM,
      then which ones to copy TO (Enter = all others).
    - Only the Preferences file is copied. Passwords, cookies, history and
      autofill data are never touched, so customer profiles stay isolated.
    - Each target's original Preferences is backed up as Preferences.bak-<timestamp>.

.EXAMPLE
    .\Copy-VivaldiSettings.ps1
    Interactive: pick source and targets from a list.

.EXAMPLE
    .\Copy-VivaldiSettings.ps1 -WhatIf
    Interactive dry run: shows what would change, writes nothing.

.EXAMPLE
    .\Copy-VivaldiSettings.ps1 -Force
    Closes Vivaldi automatically if it is running.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$UserDataPath = (Join-Path $env:LOCALAPPDATA 'Vivaldi\User Data'),
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$utf8NoBom = New-Object System.Text.UTF8Encoding $false

if (-not (Test-Path $UserDataPath)) { throw "Vivaldi user data folder not found: $UserDataPath" }

# --- 1. Discover profiles ---------------------------------------------------
$displayNames = @{}
$localState = Join-Path $UserDataPath 'Local State'
if (Test-Path $localState) {
    try {
        $ls = Get-Content $localState -Raw -Encoding UTF8 | ConvertFrom-Json
        foreach ($p in $ls.profile.info_cache.PSObject.Properties) {
            $displayNames[$p.Name] = $p.Value.name
        }
    }
    catch { Write-Verbose 'Could not read Local State; display names unavailable.' }
}

$profiles = @(
    Get-ChildItem $UserDataPath -Directory |
        Where-Object {
            ($_.Name -eq 'Default' -or $_.Name -like 'Profile *') -and
            (Test-Path (Join-Path $_.FullName 'Preferences'))
        } |
        Sort-Object { if ($_.Name -eq 'Default') { 0 } else { [int]($_.Name -replace '\D', '') } } |
        ForEach-Object {
            [PSCustomObject]@{
                Folder   = $_.Name
                Name     = if ($displayNames[$_.Name]) { $displayNames[$_.Name] } else { '(unnamed)' }
                Modified = (Get-Item (Join-Path $_.FullName 'Preferences')).LastWriteTime
            }
        }
)

if ($profiles.Count -lt 2) { throw "Found $($profiles.Count) profile(s). At least two are needed." }

function Show-Profiles($list) {
    Write-Host ''
    for ($i = 0; $i -lt $list.Count; $i++) {
        $p = $list[$i]
        Write-Host ('  [{0,2}]  {1,-30} {2,-12} last changed {3:yyyy-MM-dd HH:mm}' -f ($i + 1), $p.Name, $p.Folder, $p.Modified)
    }
    Write-Host ''
}

# --- 2. Choose SOURCE --------------------------------------------------------
Write-Host 'Vivaldi profiles found:' -ForegroundColor Cyan
Show-Profiles $profiles

do {
    $answer = Read-Host "Copy settings FROM which profile? (1-$($profiles.Count))"
    $idx = 0
    $valid = [int]::TryParse($answer, [ref]$idx) -and $idx -ge 1 -and $idx -le $profiles.Count
    if (-not $valid) { Write-Host '  Invalid choice, try again.' -ForegroundColor Red }
} until ($valid)

$source = $profiles[$idx - 1]
$sourcePrefs = Join-Path (Join-Path $UserDataPath $source.Folder) 'Preferences'

# --- 3. Choose TARGETS -------------------------------------------------------
$candidates = @($profiles | Where-Object { $_.Folder -ne $source.Folder })
Write-Host "`nSource: $($source.Name) [$($source.Folder)]" -ForegroundColor Cyan
Write-Host 'Available targets:' -ForegroundColor Cyan
Show-Profiles $candidates

do {
    $answer = Read-Host 'Copy settings TO which profiles? (e.g. 1,3,4 - press Enter for ALL)'
    if ([string]::IsNullOrWhiteSpace($answer)) {
        $targets = $candidates; $valid = $true
    }
    else {
        $nums = $answer -split '[,\s]+' | Where-Object { $_ }
        $valid = $true
        $targets = foreach ($n in $nums) {
            $t = 0
            if ([int]::TryParse($n, [ref]$t) -and $t -ge 1 -and $t -le $candidates.Count) { $candidates[$t - 1] }
            else { $valid = $false }
        }
        $targets = @($targets | Sort-Object Folder -Unique)
        if (-not $valid -or -not $targets) { Write-Host '  Invalid choice, try again.' -ForegroundColor Red; $valid = $false }
    }
} until ($valid)

Write-Host "`nWill copy settings from '$($source.Name)' to:" -ForegroundColor Yellow
$targets | ForEach-Object { Write-Host "  - $($_.Name) [$($_.Folder)]" }
if (-not $WhatIfPreference) {
    if ((Read-Host "`nProceed? (y/N)") -notmatch '^(y|yes|j|ja)$') { Write-Host 'Aborted.'; return }
}

# --- 4. Vivaldi must be closed ----------------------------------------------
$running = Get-Process -Name 'vivaldi' -ErrorAction SilentlyContinue
if ($running -and -not $WhatIfPreference) {
    if ($Force -or (Read-Host 'Vivaldi is running. Close it now? (y/N)') -match '^(y|yes|j|ja)$') {
        $running | Stop-Process -Force
        Start-Sleep -Seconds 3
    }
    else { Write-Host 'Aborted - close Vivaldi and run again.'; return }
}

# --- 5. Apply ----------------------------------------------------------------
foreach ($target in $targets) {
    $targetPrefs = Join-Path (Join-Path $UserDataPath $target.Folder) 'Preferences'
    $label = "$($target.Name) [$($target.Folder)]"

    if (-not $PSCmdlet.ShouldProcess($label, 'Overwrite Preferences with template settings')) { continue }

    $backup = "$targetPrefs.bak-$stamp"
    Copy-Item $targetPrefs $backup -Force

    try {
        # Template settings + the target's own name/avatar
        $new = Get-Content $sourcePrefs -Raw -Encoding UTF8 | ConvertFrom-Json
        $old = Get-Content $backup -Raw -Encoding UTF8 | ConvertFrom-Json
        foreach ($key in 'name', 'avatar_index', 'using_default_name', 'using_default_avatar') {
            if ($old.profile.PSObject.Properties[$key]) {
                $new.profile | Add-Member -NotePropertyName $key -NotePropertyValue $old.profile.$key -Force
            }
        }
        $json = $new | ConvertTo-Json -Depth 100 -Compress
        [System.IO.File]::WriteAllText($targetPrefs, $json, $utf8NoBom)
        Write-Host "  OK      $label" -ForegroundColor Green
    }
    catch {
        Copy-Item $sourcePrefs $targetPrefs -Force
        Write-Warning "  COPIED  $label - name merge failed, plain copy used. Rename this profile in Vivaldi."
    }
}

if (-not $WhatIfPreference) {
    Write-Host "`nDone. Backups saved as Preferences.bak-$stamp in each target folder." -ForegroundColor Cyan
}
