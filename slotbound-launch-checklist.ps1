<#
.SYNOPSIS
    Slotbound Launch Checklist — Read-Only Windows Diagnostic Script
.DESCRIPTION
    Performs non-invasive, read-only local checks on Windows (Steam paths, folder layout,
    file timestamps/sizes, and system info). Does NOT modify, delete, or upload any files,
    and does NOT require administrator privileges or changes to Windows Defender.
.NOTES
    License: MIT
#>

$ErrorActionPreference = 'SilentlyContinue'

function Get-SteamLibraries {
    $libs = @()
    $regPath = 'HKCU:\Software\Valve\Steam'
    $steamPath = (Get-ItemProperty -Path $regPath -Name 'SteamPath').SteamPath
    if (-not $steamPath) {
        $steamPath = 'C:\Program Files (x86)\Steam'
    }
    $steamPath = $steamPath -replace '/', '\'
    if (Test-Path $steamPath) {
        $libs += $steamPath
        $vdf = Join-Path $steamPath 'steamapps\libraryfolders.vdf'
        if (Test-Path $vdf) {
            $content = Get-Content -Path $vdf -Raw
            $matches = [regex]::Matches($content, '"path"\s+"([^"]+)"')
            foreach ($m in $matches) {
                $p = $m.Groups[1].Value -replace '\\', '\'
                if ((Test-Path $p) -and ($libs -notcontains $p)) {
                    $libs += $p
                }
            }
        }
    }
    return $libs
}

function Find-SteamGameDir {
    param([string[]]$FolderNames)
    foreach ($lib in (Get-SteamLibraries)) {
        foreach ($name in $FolderNames) {
            $candidate = Join-Path $lib "steamapps\common\$name"
            if (Test-Path $candidate) {
                return $candidate
            }
        }
    }
    return $null
}

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " Slotbound Launch Checklist (Read-Only Check)" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

$gameDir = Find-SteamGameDir -FolderNames @("Slotbound")
Write-Host "[Slotbound Steam Installation Check]" -ForegroundColor Yellow
if (-not $gameDir) {
    Write-Host "  Slotbound folder not found in Steam libraries." -ForegroundColor DarkYellow
} else {
    $item = Get-Item -Path $gameDir
    $isReparse = [bool]($item.Attributes -band [IO.FileAttributes]::ReparsePoint)
    Write-Host "  Install Dir  : $gameDir" -ForegroundColor Green
    Write-Host "  Symlink/Junc : $isReparse"
    if ($isReparse -and $item.Target) {
        Write-Host "  Link Target  : $($item.Target) (Exists: $(Test-Path $item.Target))"
    }

    $exe = Join-Path $gameDir "Slotbound.exe"
    if (Test-Path $exe) {
        $f = Get-Item $exe
        Write-Host "  Executable   : Found (Version: $($f.VersionInfo.FileVersion), Modified: $($f.LastWriteTime))" -ForegroundColor Green
    } else {
        Write-Host "  Executable   : Slotbound.exe not found in root folder!" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "Diagnostic complete. No files were modified." -ForegroundColor Green
Read-Host "Press Enter to exit"
