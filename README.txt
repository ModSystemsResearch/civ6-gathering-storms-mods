Civilization VI Gathering Storm DLL Patch Scripts
=================================================

Target DLL
----------
GameCore_XP2_FinalRelease.dll

Included scripts
----------------
Patch_Civ6_Allow_Water_City_Founding.ps1
Patch_Civ6_Allow_Water_Districts.ps1
Patch_Civ6_Buildings_and_Wonders_Range4.ps1
Run_All_Three_Patches.ps1

How to use one patch
--------------------
1. Put the desired script beside GameCore_XP2_FinalRelease.dll.
2. Open PowerShell in that folder.
3. Run, for example:

   powershell -ExecutionPolicy Bypass -File .\Patch_Civ6_Allow_Water_City_Founding.ps1

How to use all three
--------------------
Keep all four .ps1 files beside GameCore_XP2_FinalRelease.dll and run:

   powershell -ExecutionPolicy Bypass -File .\Run_All_Three_Patches.ps1

Order-safe behavior
-------------------
- Any individual patch can be run by itself.
- The three individual scripts can be run one after another in any order.
- Each script checks only its own patch locations, so changes made by the
  other two scripts do not cause a false version-mismatch error.
- Every script detects its own already-patched bytes and safely skips them.
- The Run All launcher can also be run again safely.

Backup behavior
---------------
The first script from this set that actually changes the DLL creates:

GameCore_XP2_FinalRelease.dll.before_first_patch_from_this_set.bak

The following scripts reuse that same backup instead of overwriting it.
On a clean DLL, this preserves the state from before any of these three
patches were applied.

Important
---------
These scripts verify the PE structure and the expected bytes at each exact
patch location. They stop without writing if the target bytes do not match.

The scripts contain no personal names, email addresses, usernames, personal
folder paths, drive letters, IP addresses, or other user-specific information.

These scripts were reviewed structurally, but a live patch test requires the
matching GameCore_XP2_FinalRelease.dll version.
