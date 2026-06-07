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

# Building/wonder scan cap:
# 1800F79EA: 83 C0 12    ADD EAX,0x12
# Change the immediate byte at 1800F79EC from 12 to 2A.
$scanInstructionVA = [UInt64]0x1800F79EA
$scanImmediateVA = [UInt64]0x1800F79EC

# Building/wonder final distance validator:
# 18025BC07: 83 F8 03    CMP EAX,0x3
# Change the immediate byte at 18025BC09 from 03 to 04.
$validatorInstructionVA = [UInt64]0x18025BC07
$validatorImmediateVA = [UInt64]0x18025BC09

$scanInstructionOffset = Convert-VaToFileOffset $scanInstructionVA $pe.ImageBase $pe.Sections
$scanImmediateOffset = Convert-VaToFileOffset $scanImmediateVA $pe.ImageBase $pe.Sections
$validatorInstructionOffset = Convert-VaToFileOffset $validatorInstructionVA $pe.ImageBase $pe.Sections
$validatorImmediateOffset = Convert-VaToFileOffset $validatorImmediateVA $pe.ImageBase $pe.Sections

if (($scanInstructionOffset + 2) -ge $bytes.Length -or ($validatorInstructionOffset + 2) -ge $bytes.Length) {
    throw "A calculated patch location is outside the DLL."
}

Write-Host "Buildings and wonders range 4 patch"
Write-Host "  DLL image base: 0x$('{0:X}' -f $pe.ImageBase)"
Write-Host "  Scan offset:      0x$('{0:X}' -f $scanInstructionOffset)"
Write-Host "  Validator offset: 0x$('{0:X}' -f $validatorInstructionOffset)"

if (($bytes[$scanInstructionOffset] -ne 0x83) -or ($bytes[$scanInstructionOffset + 1] -ne 0xC0)) {
    throw "Expected the scan instruction to begin with 83 C0, but found $($bytes[$scanInstructionOffset].ToString('X2')) $($bytes[$scanInstructionOffset + 1].ToString('X2')). No patch was made."
}

if (($bytes[$validatorInstructionOffset] -ne 0x83) -or ($bytes[$validatorInstructionOffset + 1] -ne 0xF8)) {
    throw "Expected the validator instruction to begin with 83 F8, but found $($bytes[$validatorInstructionOffset].ToString('X2')) $($bytes[$validatorInstructionOffset + 1].ToString('X2')). No patch was made."
}

$scanState =
    if ($bytes[$scanImmediateOffset] -eq 0x12) { "Original" }
    elseif ($bytes[$scanImmediateOffset] -eq 0x2A) { "Patched" }
    else { "Unknown" }

$validatorState =
    if ($bytes[$validatorImmediateOffset] -eq 0x03) { "Original" }
    elseif ($bytes[$validatorImmediateOffset] -eq 0x04) { "Patched" }
    else { "Unknown" }

if ($scanState -eq "Unknown") {
    throw "Expected scan byte 12 or already-patched byte 2A, but found $($bytes[$scanImmediateOffset].ToString('X2')). No patch was made."
}

if ($validatorState -eq "Unknown") {
    throw "Expected validator byte 03 or already-patched byte 04, but found $($bytes[$validatorImmediateOffset].ToString('X2')). No patch was made."
}

if (($scanState -eq "Patched") -and ($validatorState -eq "Patched")) {
    Write-Host "  Status: already fully patched; no change needed."
    return
}

if (!(Test-Path -LiteralPath $sharedBackup -PathType Leaf)) {
    Copy-Item -LiteralPath $dll -Destination $sharedBackup
    Write-Host "  Shared backup created: $(Split-Path $sharedBackup -Leaf)"
} else {
    Write-Host "  Shared backup already exists: $(Split-Path $sharedBackup -Leaf)"
}

if ($scanState -eq "Original") {
    $bytes[$scanImmediateOffset] = 0x2A
}

if ($validatorState -eq "Original") {
    $bytes[$validatorImmediateOffset] = 0x04
}

[System.IO.File]::WriteAllBytes($dll, $bytes)

Write-Host "  Status: patch successful."

if ($scanState -eq "Original") {
    Write-Host "  Changed scan byte: 12 -> 2A"
} else {
    Write-Host "  Scan byte was already patched: 2A"
}

if ($validatorState -eq "Original") {
    Write-Host "  Changed validator byte: 03 -> 04"
} else {
    Write-Host "  Validator byte was already patched: 04"
}
