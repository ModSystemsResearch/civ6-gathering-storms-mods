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

function Test-BytesMatch {
    param(
        [byte[]]$Data,
        [int]$Offset,
        [byte[]]$Expected
    )

    for ($i = 0; $i -lt $Expected.Length; $i++) {
        if ($Data[$Offset + $i] -ne $Expected[$i]) {
            return $false
        }
    }

    return $true
}

[byte[]]$bytes = [System.IO.File]::ReadAllBytes($dll)
$pe = Get-PeInfo $bytes

# Water-district rejection jump:
# 18025A839: 0F 85 E7 FD FF FF    JNZ failure
# Replace it with six NOPs.
$jumpVA = [UInt64]0x18025A839
$jumpOffset = Convert-VaToFileOffset $jumpVA $pe.ImageBase $pe.Sections
$original = [byte[]](0x0F, 0x85, 0xE7, 0xFD, 0xFF, 0xFF)
$patched = [byte[]](0x90, 0x90, 0x90, 0x90, 0x90, 0x90)

if (($jumpOffset + $original.Length - 1) -ge $bytes.Length) {
    throw "The calculated patch location is outside the DLL."
}

Write-Host "Water districts patch"
Write-Host "  DLL image base: 0x$('{0:X}' -f $pe.ImageBase)"
Write-Host "  Patch offset:   0x$('{0:X}' -f $jumpOffset)"

if (Test-BytesMatch $bytes $jumpOffset $patched) {
    Write-Host "  Status: already patched; no change needed."
    return
}

if (!(Test-BytesMatch $bytes $jumpOffset $original)) {
    $found = (($bytes[$jumpOffset..($jumpOffset + 5)] | ForEach-Object { $_.ToString('X2') }) -join " ")
    throw "Expected bytes 0F 85 E7 FD FF FF, but found $found. This may be the wrong DLL version or a differently modified DLL. No patch was made."
}

if (!(Test-Path -LiteralPath $sharedBackup -PathType Leaf)) {
    Copy-Item -LiteralPath $dll -Destination $sharedBackup
    Write-Host "  Shared backup created: $(Split-Path $sharedBackup -Leaf)"
} else {
    Write-Host "  Shared backup already exists: $(Split-Path $sharedBackup -Leaf)"
}

for ($i = 0; $i -lt $patched.Length; $i++) {
    $bytes[$jumpOffset + $i] = $patched[$i]
}

[System.IO.File]::WriteAllBytes($dll, $bytes)

Write-Host "  Status: patch successful."
Write-Host "  Changed: 0F 85 E7 FD FF FF -> 90 90 90 90 90 90"
