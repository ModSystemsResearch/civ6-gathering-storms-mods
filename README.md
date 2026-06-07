# Civilization VI Gathering Storm DLL Patch Scripts

PowerShell scripts that modify selected hard-coded placement rules in **Sid Meier's Civilization VI: Gathering Storm**.

These scripts can enable:

* Water city founding
* District placement on water
* Building and wonder placement out to range 4

Each patch can be run individually, in any order, or all three can be applied with the included launcher.

> [!WARNING]
> These scripts directly modify `GameCore_XP2_FinalRelease.dll`. Always keep an untouched backup. Game updates and Steam file verification may replace the patched DLL.

---

## Included Scripts

### `Patch_Civ6_Allow_Water_City_Founding.ps1`

Removes the tested DLL check that rejects founding a city on a water tile.

The script:

* Targets the DLL beside the script
* Verifies the expected original bytes
* Detects an already-installed patch
* Stops safely if the bytes do not match
* Creates a backup before modifying the DLL

This changes a specific DLL-side rejection check. Other XML, SQL, Lua, map, unit, UI, and gameplay rules may still affect whether water cities function correctly.

---

### `Patch_Civ6_Allow_Water_Districts.ps1`

Removes the tested DLL check that rejects district placement on water tiles.

The script:

* Targets the DLL beside the script
* Verifies the expected original bytes
* Detects an already-installed patch
* Stops safely if the bytes do not match
* Uses the shared pre-patch backup

This does not automatically make every district compatible with every water tile. District requirements, terrain rules, adjacency rules, visuals, and other mods may still affect placement.

---

### `Patch_Civ6_Buildings_and_Wonders_Range4.ps1`

Extends the tested building and wonder placement checks to range 4.

This script modifies two related locations:

* The building/wonder scan cap
* The final distance validator

Each location is checked independently. If one part is already patched, the script applies only the missing change.

> [!NOTE]
> Earlier development versions may have used a district-related filename. The script contents and byte locations determine what the patch actually changes.

---

### `Run_All_Three_Patches.ps1`

Runs all three patch scripts:

1. Water city founding
2. Water districts
3. Buildings and wonders range 4

The launcher stops if a required script is missing or one of the patches encounters an unexpected DLL.

It is safe to run the launcher more than once. Already-installed patches are detected and skipped.

---

## Requirements

* Windows
* Civilization VI with Gathering Storm
* `GameCore_XP2_FinalRelease.dll`
* Windows PowerShell 5.1 or PowerShell 7
* A DLL build containing the exact byte patterns expected by these scripts

No external PowerShell modules are required.

---

## Folder Setup

Place the scripts beside the DLL:

```text
GameCore_XP2_FinalRelease.dll
Patch_Civ6_Allow_Water_City_Founding.ps1
Patch_Civ6_Allow_Water_Districts.ps1
Patch_Civ6_Buildings_and_Wonders_Range4.ps1
Run_All_Three_Patches.ps1
```

The scripts use `$PSScriptRoot`, so they always target the DLL in the same folder. They do not contain a hard-coded Steam path, Windows username, drive letter, or other personal path.

---

## Run One Patch

Open PowerShell in the folder containing the scripts and DLL.

### Water city founding

```powershell
powershell -ExecutionPolicy Bypass -File .\Patch_Civ6_Allow_Water_City_Founding.ps1
```

### Water districts

```powershell
powershell -ExecutionPolicy Bypass -File .\Patch_Civ6_Allow_Water_Districts.ps1
```

### Buildings and wonders range 4

```powershell
powershell -ExecutionPolicy Bypass -File .\Patch_Civ6_Buildings_and_Wonders_Range4.ps1
```

PowerShell 7 users can replace `powershell` with `pwsh`.

---

## Run All Three Patches

Keep all four `.ps1` files beside the DLL and run:

```powershell
powershell -ExecutionPolicy Bypass -File .\Run_All_Three_Patches.ps1
```

The individual patch scripts can also be run one after another in any order.

Each script checks only its own patch locations, so a change made by one script will not cause the other scripts to falsely reject the DLL.

---

## Backup Behavior

The first script that actually modifies the DLL creates:

```text
GameCore_XP2_FinalRelease.dll.before_first_patch_from_this_set.bak
```

The remaining scripts preserve and reuse that backup instead of overwriting it.

For maximum safety, also make your own untouched backup:

```text
GameCore_XP2_FinalRelease.dll.VANILLA_BACKUP
```

Store the untouched backup outside the active game folder.

---

## Restoring the Original DLL

### Restore from the generated backup

1. Close Civilization VI.
2. Remove or rename the patched DLL.
3. Copy:

```text
GameCore_XP2_FinalRelease.dll.before_first_patch_from_this_set.bak
```

4. Rename the copy to:

```text
GameCore_XP2_FinalRelease.dll
```

### Restore through Steam

Steam's file verification can restore the official DLL, but it will remove all three patches.

After an update or verification, only run the scripts again if their expected-byte checks pass.

---

## Safety Checks

Before modifying the DLL, each script:

* Confirms the target file exists
* Confirms it is a valid 64-bit PE DLL
* Reads the PE image base and section table
* Converts the tested virtual address to a file offset
* Verifies the exact expected original bytes
* Detects its own already-patched bytes
* Refuses to write when unexpected bytes are found
* Creates or preserves the shared backup

The scripts do not blindly search and replace every matching byte sequence.

---

## Troubleshooting

### DLL not found

Error:

```text
Could not find GameCore_XP2_FinalRelease.dll beside this script.
```

Move the script into the same folder as:

```text
GameCore_XP2_FinalRelease.dll
```

Then run the saved `.ps1` file again.

---

### Unexpected bytes

Error:

```text
Expected bytes ... but found ...
```

Possible causes:

* The DLL is from a different Civilization VI build
* Civilization VI was updated
* Another patch changed the same location
* The wrong DLL was selected
* The DLL is damaged
* The tested patch locations do not apply to that version

Do not force the patch. Restore a clean DLL and verify that it is the Gathering Storm `GameCore_XP2_FinalRelease.dll`.

---

### PowerShell blocks the script

Use a one-time execution-policy override:

```powershell
powershell -ExecutionPolicy Bypass -File .\Run_All_Three_Patches.ps1
```

This does not permanently change the system-wide execution policy.

---

### An update removed the patches

Steam and Civilization VI updates can replace the DLL.

Restore or obtain the updated clean DLL and run the scripts again. If the byte checks fail, the scripts have not been verified for that DLL build.

---

### The patch succeeds but placement still does not work

These scripts modify specific DLL checks only. Civilization VI may apply additional restrictions through:

* XML or SQL definitions
* Lua scripts
* District or wonder requirements
* Terrain and feature requirements
* Map generation
* Unit placement rules
* UI validation
* Expansion rules
* Other mods

A successful patch confirms only that the tested DLL instruction was modified.

---

## Compatibility

These scripts are intended for:

```text
GameCore_XP2_FinalRelease.dll
```

They are not intended for similarly named base-game or other-expansion DLLs.

Compatibility is determined by the exact bytes inside the DLL, not merely by the filename. A failed expected-byte check means that DLL version should be treated as unsupported until independently verified.

---

## Limitations

* DLL modification can cause crashes or unexpected behavior.
* Water cities may require additional gameplay, UI, AI, art, XML, SQL, or Lua changes.
* Water districts may require compatible district definitions and assets.
* AI compatibility is not guaranteed solely by removing a placement check.
* Multiplayer players should use identical gameplay DLL modifications.
* Existing saves may behave differently after core placement rules change.
* Game updates can replace or invalidate the patches.

Use these scripts at your own risk and keep backups.

---

## Repository Layout

```text
.
├── Patch_Civ6_Allow_Water_City_Founding.ps1
├── Patch_Civ6_Allow_Water_Districts.ps1
├── Patch_Civ6_Buildings_and_Wonders_Range4.ps1
├── Run_All_Three_Patches.ps1
└── README.md
```

---

## Privacy

The scripts contain no personal names, email addresses, Windows usernames, personal folder paths, drive letters, IP addresses, or other user-specific information.

All file paths are resolved relative to the script location.

---

## License

No license has been selected yet.

Add a license before publishing if other users should be allowed to redistribute, modify, or include the scripts in other projects. Common choices for small utility scripts include:

* MIT
* BSD 2-Clause
* GPL-3.0

---

## Disclaimer

This is an unofficial community project and is not affiliated with or endorsed by Firaxis Games, 2K, Take-Two Interactive, or Microsoft.

Civilization VI and Gathering Storm are trademarks of their respective owners.
::: 
