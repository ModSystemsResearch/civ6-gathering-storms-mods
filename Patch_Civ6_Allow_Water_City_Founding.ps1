$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($PSScriptRoot)) {
    throw "Run this saved .ps1 script as a file. Do not paste its contents directly into PowerShell."
}

$dll = Join-Path $PSScriptRoot "GameCore_XP2_FinalRelease.dll"
$sharedBackup = Join-Path $PSScriptRoot "GameCore_XP2_FinalRelease.dll.before_first_patch_from_this_set.bak"

if (!(Test-Path -LiteralPath $dll -PathType Leaf)) {
    throw "Could not find GameCore_XP2_FinalRelease.dll beside this script."
}

function Read-U16 {
    param([byte[]]$Data, [int]$Offset)
    return [BitConverter]::ToUInt16($Data, $Offset)
}

function Read-U32 {
    param([byte[]]$Data, [int]$Offset)
    return [BitConverter]::ToUInt32($Data, $Offset)
}

function Read-U64 {
    param([byte[]]$Data, [int]$Offset)
    return [BitConverter]::ToUInt64($Data, $Offset)
}

function Get-PeInfo {
    param([byte[]]$Data)

    if ($Data.Length -lt 0x40) {
        throw "The DLL is too small to be a valid PE file."
    }

    $peOffset = Read-U32 $Data 0x3C
    if (($peOffset + 24) -ge $Data.Length) {
        throw "The DLL has an invalid PE header offset."
    }

    $signature = [System.Text.Encoding]::ASCII.GetString($Data, $peOffset, 4)
    if ($signature -ne "PE`0`0") {
        throw "GameCore_XP2_FinalRelease.dll is not a valid PE file."
    }

    $numberOfSections = Read-U16 $Data ($peOffset + 6)
    $sizeOfOptionalHeader = Read-U16 $Data ($peOffset + 20)
    $optionalHeaderOffset = $peOffset + 24

    if ((Read-U16 $Data $optionalHeaderOffset) -ne 0x20B) {
        throw "Expected a 64-bit PE32+ DLL."
    }

    $imageBase = Read-U64 $Data ($optionalHeaderOffset + 24)
    $sectionTableOffset = $optionalHeaderOffset + $sizeOfOptionalHeader
    $sections = @()

    for ($i = 0; $i -lt $numberOfSections; $i++) {
        $sectionOffset = $sectionTableOffset + ($i * 40)

        if (($sectionOffset + 39) -ge $Data.Length) {
            throw "The DLL contains an invalid PE section table."
        }

        $sections += [PSCustomObject]@{
            VirtualSize      = Read-U32 $Data ($sectionOffset + 8)
            VirtualAddress   = Read-U32 $Data ($sectionOffset + 12)
            SizeOfRawData    = Read-U32 $Data ($sectionOffset + 16)
            PointerToRawData = Read-U32 $Data ($sectionOffset + 20)
        }
    }

    return [PSCustomObject]@{
        ImageBase = $imageBase
        Sections  = $sections
    }
}

function Convert-VaToFileOffset {
    param(
        [UInt64]$VA,
        [UInt64]$ImageBase,
        $Sections
    )

    if ($VA -lt $ImageBase) {
        throw "VA 0x$('{0:X}' -f $VA) is below the DLL image base."
    }

    $rva = $VA - $ImageBase

    foreach ($section in $Sections) {
        $start = [UInt64]$section.VirtualAddress
        $size = [Math]::Max([UInt64]$section.VirtualSize, [UInt64]$section.SizeOfRawData)
        $end = $start + $size

        if (($rva -ge $start) -and ($rva -lt $end)) {
            return [int]([UInt64]$section.PointerToRawData + ($rva - $start))
        }
    }

    throw "Could not map VA 0x$('{0:X}' -f $VA) to a DLL file offset."
}

[byte[]]$bytes = [System.IO.File]::ReadAllBytes($dll)
$pe = Get-PeInfo $bytes

# Water-city rejection jump:
# 180144909: 75 CD    JNZ failure
# Replace it with NOP NOP.
$jumpVA = [UInt64]0x180144909
$jumpOffset = Convert-VaToFileOffset $jumpVA $pe.ImageBase $pe.Sections

if (($jumpOffset + 1) -ge $bytes.Length) {
    throw "The calculated patch location is outside the DLL."
}

$old0 = $bytes[$jumpOffset]
$old1 = $bytes[$jumpOffset + 1]

Write-Host "Water city founding patch"
Write-Host "  DLL image base: 0x$('{0:X}' -f $pe.ImageBase)"
Write-Host "  Patch offset:   0x$('{0:X}' -f $jumpOffset)"

if (($old0 -eq 0x90) -and ($old1 -eq 0x90)) {
    Write-Host "  Status: already patched; no change needed."
    return
}

if (($old0 -ne 0x75) -or ($old1 -ne 0xCD)) {
    throw "Expected bytes 75 CD, but found $($old0.ToString('X2')) $($old1.ToString('X2')). This may be the wrong DLL version or a differently modified DLL. No patch was made."
}

if (!(Test-Path -LiteralPath $sharedBackup -PathType Leaf)) {
    Copy-Item -LiteralPath $dll -Destination $sharedBackup
    Write-Host "  Shared backup created: $(Split-Path $sharedBackup -Leaf)"
} else {
    Write-Host "  Shared backup already exists: $(Split-Path $sharedBackup -Leaf)"
}

$bytes[$jumpOffset] = 0x90
$bytes[$jumpOffset + 1] = 0x90
[System.IO.File]::WriteAllBytes($dll, $bytes)

Write-Host "  Status: patch successful."
Write-Host "  Changed: 75 CD -> 90 90"
