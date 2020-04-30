# Fallout 76 Mod Bunduru

## A Super Basic Mod Bundler

This is not a mod manager. The idea is that you use the tools already in windows and manage your own mods in a folder and just run this script. It will bundle everything up in the correct .ba2 formats and copy them to your Fallout 76 installation.

### Quick Start

Put Bunduru76.ps1 somewhere.

Right-click and run with powershell or hit Win+R and type in the following: `powershell.exe -ExecutionPolicy Bypass -File <path to>\Bunduru76.ps1`

**Make sure to replace all the `<path to>` with real, actual paths to those folders** (see below for details)

When run with no parameters, the script will prompt you for your folder locations and give you the opportunity to save a shortcut to save time later.

### Prerequisites

You will need a copy of Archive2 from the Creation Kit. You can get this from the Bethesda Launcher.

To make the bundle(s) work with Fallout 76, you need to set up Fallout76Custom.ini. If you need to add this stuff, the tool will let you know what to add and be generally helpful and nice about it.

## How to Mods

Put all your mods in a folder. If you download them archived, extract them first.

This tool can work with mods that are either .ba2 or loose files. Your mod folder can contain one level of subfolders for organization. Appropriately named loose folders (eg. strings, meshes, etc) and .ba2 files in the mod folder root will be processed as well.

Items are processed in alphabetical order and any item starting with "." or "_" will be skipped.

Example:

* D:\Path\To\My\Mods\
  * _Glow\
  * BetterInventory\
    * betterinventory.ba2
  * Lowered Weapons\
    * meshes\
  * tzmap.ba2

_Glow will be ignored, betterinventory2.ba2 will be unpacked, meshes will be copied, and tzmap.ba2 will unpacked. In that order. Duplicates are overwritten, so keep order in mind.

_Note_: Will not work with nested subfolders or archived mods, please don't ask.


## How to Bundles

Running as a PowerShell command:

`PS C:\> .\path\to\bunduru76.ps1 -Archive2 .\path\to\Archive2\ -Mods .\path\to\Mods\ -Game .\path\to\Fallout76`

It can be also run from a shortcut for ez-pz bundling (see -Save parameter below).

### Parameters

All folder parameters are required. Relative paths are ok if running from the command line, but it's recommended to use absolute paths if using a shortcut.

`-Archive <path>` - Required - Folder containing Archive2.exe

`-Mods <path>` - Required - Folder containing your mods

`-Game <path>` - Required - Folder containing your Fallout 76 installation

`-Save` - _Optional_ - If set, will generate a shortcut with the same settings and put it in your mod folder. You can copy or move it anywhere and it will still work (or rename it if you hate stupid jokes).

`-Clean` - _Optional_ - If set, will delete the generated .unpacked folder after bundling.

`-Interactive` - _Optional_ - If set, forces the folder selection dialogs, but will still default them to CLI parameters.


## How do I...

### Load the Bundle into Fallout 76?

The bundler will give you some advice if you are missing the requisite ini settings, but in general, you can just add the following to your Fallout76Custom.ini (usually in `My Documents\My Games\Fallout 76`):

```
[Archive]
sResourceArchive2List=Bunduru76_General.ba2,Bunduru76_Textures.ba2
bInvalidateOlderFiles=1
sResourceDataDirsFinal=STRINGS\
```

You need at least `sResourceArchive2List=Bunduru76_General.ba2`, but leaving the rest won't hurt anything (you may want to check that there's not already a strings folder in your Data\\).

### Disable or Enable Mods?

To disable a mod, rename the file/folder containing the mod and add a dot or underscore to the front: eg. `MyMod\` becomes `_MyMod\`. The bundler will skip anything that starts with "\_". To enable again, just remove the "\_".

You could also create a `_Disabled` folder and chuck disabled mods in there.

### Change the Load Order of Mods?

Mods are loaded in alphabetical order. If you want to set a specific order, prepend the file/folder names with numbers:

* MyDependentMod\
* MyMod\

Becomes

* 1 MyMod\
* MyDependentMod\

Yay

### Save My Settings?

Pass in the `-Save` parameter, it will create a shortcut in your mods folder. 2EZ

### Clean Up?

By default, the bundler will leave the unpacked files in your Mod folder in `.unpacked`. You can delete this if you want, or you can pass in the `-Clean` parameter to remove it automatically. Leaving it can help debug ordering problems.
