<#
.SYNOPSIS
    Optional Dogs Playbook step: reports whether this machine's NVIDIA GPU(s)
    can use the gpu-unlock tensor-core unlock.

.DESCRIPTION
    READ-ONLY. This script changes nothing: no drivers, no boot entries, no
    firmware, no registry. It never touches the network.

    The unlock itself (https://github.com/Zagitta/gpu-unlock) is a Linux
    kernel module that runs before the NVIDIA driver loads. On Windows the
    only route is an experimental UEFI pre-boot port
    (https://github.com/impacifist/Windows-GPU-UNLOCK) that needs Secure Boot
    off, BitLocker off and a separate EFI System Partition. Neither can be
    applied safely from inside a playbook, so this step only tells you where
    you stand and what you would need.

    Writes:
      %SystemDrive%\DogsPlaybook\GPU-UNLOCK\report.txt
      %SystemDrive%\DogsPlaybook\GPU-UNLOCK\report.json
      %PUBLIC%\Desktop\GPU-Unlock-Report.txt   (copy of report.txt)

    Always exits 0 so it can never fail a playbook run.
#>
[CmdletBinding()]
param(
    [string]$DevicesPath,
    [string]$OutDir,
    [switch]$NoDesktopCopy
)

$ErrorActionPreference = 'Continue'
# Windows PowerShell 5.1 leaves $PSScriptRoot empty inside param() defaults.
$here = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
if (-not $DevicesPath) { $DevicesPath = Join-Path $here 'supported-devices.json' }
if (-not $OutDir) { $OutDir = Join-Path $env:SystemDrive 'DogsPlaybook\GPU-UNLOCK' }

function Get-NvidiaGpus {
    $found = @()
    try {
        $found = @(Get-CimInstance -ClassName Win32_PnPEntity -ErrorAction Stop |
            Where-Object { $_.PNPDeviceID -like 'PCI\VEN_10DE&DEV_*' -and ($_.PNPClass -eq 'Display' -or $_.PNPClass -eq '3D Video Controller') })
    } catch { }
    if ($found.Count -eq 0) {
        try {
            $found = @(Get-CimInstance -ClassName Win32_VideoController -ErrorAction Stop |
                Where-Object { $_.PNPDeviceID -like 'PCI\VEN_10DE&DEV_*' })
        } catch { }
    }
    foreach ($d in $found) {
        $m = [regex]::Match($d.PNPDeviceID, 'DEV_([0-9A-Fa-f]{4})')
        [pscustomobject]@{
            Name        = $d.Name
            DeviceId    = $m.Groups[1].Value.ToLower()
            PnpDeviceId = $d.PNPDeviceID
        }
    }
}

function Test-IsPortable {
    # SMBIOS chassis types for laptops/notebooks/tablets/convertibles.
    $portable = 8, 9, 10, 11, 12, 14, 18, 21, 30, 31, 32
    try {
        $types = @((Get-CimInstance Win32_SystemEnclosure -ErrorAction Stop).ChassisTypes)
        if ($types | Where-Object { $portable -contains [int]$_ }) { return $true }
    } catch { }
    try { if (@(Get-CimInstance Win32_Battery -ErrorAction Stop).Count -gt 0) { return $true } } catch { }
    return $false
}

function Get-SecureBootState {
    try { if (Confirm-SecureBootUEFI -ErrorAction Stop) { 'on' } else { 'off' } }
    catch { 'unknown (legacy BIOS or not readable)' }
}

function Get-BitLockerState {
    try {
        $v = Get-BitLockerVolume -MountPoint $env:SystemDrive -ErrorAction Stop
        "$($v.ProtectionStatus) / $($v.VolumeStatus)"
    } catch { 'unknown' }
}

$table = $null
try { $table = Get-Content -Raw -Path $DevicesPath -ErrorAction Stop | ConvertFrom-Json }
catch { Write-Warning "Device table not found or unreadable: $DevicesPath" }

$lookup = @{}
if ($table) { foreach ($d in $table.devices) { $lookup[$d.id] = $d } }

$isPortable = Test-IsPortable
$machine = try { (Get-CimInstance Win32_ComputerSystem -ErrorAction Stop) } catch { $null }
$gpus = @(Get-NvidiaGpus)

$results = foreach ($g in $gpus) {
    $entry = $lookup[$g.DeviceId]
    if (-not $entry) {
        $verdict = 'not-supported'
        $detail  = "PCI ID 10de:$($g.DeviceId) is not in gpu-unlock's supported list (pinned commit $($table.commit)). Nothing to do."
    } else {
        $fam = $table.families.($entry.family)
        if ($entry.family -eq 'GA' -and -not $isPortable) {
            $verdict = 'windows-port-candidate'
            $detail  = "$($entry.chip) ($($fam.generation), $($fam.series)). Linux module: $($fam.linuxStatus). The experimental Windows UEFI port has success reports for some desktop RTX 30 card + motherboard combinations. Check its compatibility guide before trying anything."
        } else {
            $verdict = 'linux-only'
            $detail  = "$($entry.chip) ($($fam.generation), $($fam.series)). Supported by the Linux module ($($fam.linuxStatus)). The Windows port does not cover this card."
        }
        if ($isPortable) {
            $detail += ' This is a laptop: the unlock is lost whenever the dGPU is powered off (Optimus does this constantly), so expect little or no benefit.'
        }
    }
    [pscustomobject]@{
        name        = $g.Name
        pciId       = "10de:$($g.DeviceId)"
        pnpDeviceId = $g.PnpDeviceId
        verdict     = $verdict
        detail      = $detail
    }
}

$report = [ordered]@{
    generated     = (Get-Date).ToString('s')
    machine       = if ($machine) { "$($machine.Manufacturer) $($machine.Model)" } else { 'unknown' }
    portable      = $isPortable
    secureBoot    = Get-SecureBootState
    bitLocker     = Get-BitLockerState
    tableCommit   = if ($table) { $table.commit } else { $null }
    gpus          = @($results)
}

$lines = @(
    'Dogs Playbook - GPU tensor unlock check (read-only)'
    '==================================================='
    "Generated:   $($report.generated)"
    "Machine:     $($report.machine)"
    "Laptop:      $($report.portable)"
    "Secure Boot: $($report.secureBoot)"
    "BitLocker:   $($report.bitLocker)"
    ''
)
if ($report.gpus.Count -eq 0) {
    $lines += 'No NVIDIA GPU found. Nothing to do.'
} else {
    foreach ($r in $report.gpus) {
        $lines += "$($r.name)  [$($r.pciId)]"
        $lines += "  Verdict: $($r.verdict)"
        $lines += "  $($r.detail)"
        $lines += ''
    }
}
$lines += @(
    'Nothing was changed on this system.'
    ''
    'What gpu-unlock does: doubles FP16/BF16/TF32 tensor-core throughput on'
    'GeForce RTX 20/30/40 cards. It helps AI training, prefill and image'
    'generation. It does nothing for gaming, FP32, INT8/FP8 or token decode.'
    ''
    "Linux module:  $(if ($table) { $table.source } else { 'https://github.com/Zagitta/gpu-unlock' })"
    "Windows port:  $(if ($table) { $table.windowsPort.url } else { 'https://github.com/impacifist/Windows-GPU-UNLOCK' })"
    'Beware of third-party "installers"; upstream says it ships none.'
)

try {
    New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
    $txt = Join-Path $OutDir 'report.txt'
    $lines | Set-Content -Path $txt -Encoding UTF8
    $report | ConvertTo-Json -Depth 5 | Set-Content -Path (Join-Path $OutDir 'report.json') -Encoding UTF8
    if (-not $NoDesktopCopy -and $env:PUBLIC) {
        Copy-Item -Path $txt -Destination (Join-Path $env:PUBLIC 'Desktop\GPU-Unlock-Report.txt') -Force -ErrorAction SilentlyContinue
    }
} catch {
    Write-Warning "Could not write report: $_"
}

$lines | ForEach-Object { Write-Host $_ }
exit 0
