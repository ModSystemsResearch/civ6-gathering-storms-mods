$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($PSScriptRoot)) {
    throw "Run this saved .ps1 script as a file. Do not paste its contents directly into PowerShell."
}

$dll = Join-Path $PSScriptRoot "GameCore_XP2_FinalRelease.dll"

if (!(Test-Path -LiteralPath $dll -PathType Leaf)) {
    throw "Could not find GameCore_XP2_FinalRelease.dll beside this script."
}

$scripts = @(
    "Patch_Civ6_Allow_Water_City_Founding.ps1",
    "Patch_Civ6_Allow_Water_Districts.ps1",
    "Patch_Civ6_Buildings_and_Wonders_Range4.ps1"
)

Write-Host "Applying all three Civilization VI DLL patches..."
Write-Host ""

foreach ($scriptName in $scripts) {
    $scriptPath = Join-Path $PSScriptRoot $scriptName

    if (!(Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
        throw "Required patch script is missing: $scriptName"
    }

    Write-Host "============================================================"
    Write-Host "Running: $scriptName"
    Write-Host "============================================================"

    & $scriptPath

    Write-Host ""
}

Write-Host "============================================================"
Write-Host "All three patch scripts completed successfully."
Write-Host "Running this launcher again is safe; installed patches will be skipped."
Write-Host "============================================================"
