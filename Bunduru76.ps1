<#
.SYNOPSIS
    Mod bundler for Fallout 76
.DESCRIPTION
    Bundles individual mods into .ba2 file(s) for use with Fallout 76. This tool can work with
    mods that are either .ba2 or loose files. Your mod folder can contain one level of subfolders,
    and ba2 files and "magic" loose folders in the mod folder root will be processed as well.
    Items are processed in alphabetical order and any item starting with "." or "_" will be skipped.

    Example:
    D:\Path\To\My\Mods\
        > _Glow\
        > BetterInventory\
            > betterinventory.ba2
        > Lowered Weapons\
            > meshes\
        > tzmap.ba2

    To make the bundle work with Fallout 76, add the following to your Fallout76Custom.ini (in My Documents):
        [Archive]
        sResourceArchive2List=Bunduru76_General.ba2,Bunduru76_Textures.ba2
        bInvalidateOlderFiles=1
        sResourceDataDirsFinal=STRINGS\

    Note: Will not work with nested subfolders or archived mods, please don't ask.
.PARAMETER Archive2
    Path to a folder containing Archive2.exe.
.PARAMETER Mods
    Path to a folder containing mods or mod sub-folders (.ba2 or loose).
.PARAMETER Game
    Path to your Fallout 76 installation folder.
.PARAMETER Save
    Save a shortcut in the mods folder to bundle these mods again.
.PARAMETER Clean
    Remove unpacked files after bundling.
.EXAMPLE
    C:\PS> .\path\to\bunduru76.ps1 -Archive2 .\path\to\Archive2\ -Mods .\path\to\Mods\ -Game .\path\to\Fallout76
    All parameters should be folders, Archive2 and Game parameters should be the directory that
    contains Archive2.exe and Fallout76.exe (and \Data) respectively.

    Recommended to put in a shortcut for ez-pz running
#>
[CmdletBinding()]
Param (
    [Parameter(Mandatory=$True)]
    [ValidateScript({ Test-Path -Path $_ -PathType Container -IsValid })]
    [string]$Archive2,

    [Parameter(Mandatory=$True)]
    [ValidateScript({ Test-Path -Path $_ -PathType Container -IsValid })]
    [string]$Mods,

    [Parameter(Mandatory=$True)]
    [ValidateScript({ Test-Path -Path $_ -PathType Container -IsValid })]
    [string]$Game,

    [switch]$Save,
    [switch]$Clean
)

# Normalize paths. Resolve-Path has a nice side effect of throwing a fit if the path doesn't exist

$Archive2Path = Resolve-Path $Archive2
$Archive2 = Resolve-Path "$Archive2Path\Archive2.exe"
$Mods = Resolve-Path $Mods
$Game = Resolve-Path $Game
$Data = Resolve-Path "$Game\Data\"
$Unpacked = "$($Mods).unpacked\"
$Bundle = "$Data\Bunduru76_General.ba2"
$BundleTex = "$Data\Bunduru76_Textures.ba2"

$HasStrings = $False
$HasTextures = $False

# Constants and Helpers

$IniFile = "$([Environment]::GetFolderPath("MyDocuments"))\My Games\Fallout 76\Fallout76Custom.ini"
$LnkFile = "$($Mods)\Bunduru76.lnk"
$Loosies = @('effects', 'interface', 'meshes', 'strings', 'terrain', 'textures')
$ColorHead = 'White'
$ColorCommand = 'Gray'
$ColorNotice = 'Cyan'
$ColorWarn = 'Red'
$ColorError = 'Red'

function IsFolder($Path)
{
    return Test-Path -Path $Path -PathType Container -IsValid
}

function IsBa2($Path)
{
    $Ext = [System.IO.Path]::GetExtension($Path)
    return $Ext -eq '.ba2'
}

function IsLoose($Path)
{
    $Path = [System.IO.Path]::GetFileName($Path)
    return ($Loosies.Contains($Path.ToLower())) -And (IsFolder($Path))
}

function ModUnpack($Path)
{
    $Name = $Path -replace [Regex]::Escape($Mods), ''
    Write-Host " > Unpacking $Name" -ForegroundColor $ColorCommand

    & $Archive2 "$Path" -extract="$Unpacked" | Out-String | Write-Verbose
}

function ModCopy($Path)
{
    $Name = $Path -replace [Regex]::Escape($Mods), ''
    Write-Host " > Copying $Name" -ForegroundColor $ColorCommand

    Copy-Item -Path $Path -Destination $Unpacked -Recurse -Force
}


# Make sure Archive2 is really Archive2

try {
    $Output = (& $Archive2 -?) | Out-String
    if (-Not ($Output -match 'Archive2 <archive, files\/folders>')) { throw '' }
} catch {
    Write-Host "Supplied Archive2.exe path does not appear to be valid: $Archive2" -ForegroundColor $ColorError
    Exit 1
}

# All good probably. Let's do this!

Write-Host "`n--==[ Fallout 76 Mod Bunduru ]==--" -ForegroundColor $ColorHead
Write-Host "  Archive2   > $Archive2"
Write-Host "  Mods       > $Mods"
# Write-Host "  Unpacked   > $Unpacked"
Write-Host "  Fallout 76 > $Game"
# Write-Host "  Data       > $Data"
Write-Host ""

# Clear staging folder

Remove-Item -ErrorAction Ignore -Recurse -Force $Unpacked | Out-String | Write-Verbose
New-Item -ItemType Directory -Force -Path $Unpacked | Out-String | Write-Verbose
$Unpacked = Resolve-Path $Unpacked

# Loop through each source, look for special directories or ba2, put them all in the staging folder

Write-Host "--> Getting mods from $($Mods)..." -ForegroundColor $ColorNotice

$Sources = Get-ChildItem $Mods -Exclude .*,_* | Sort-Object
Foreach ($Source in $Sources) {
    # $SourceName = [System.IO.Path]::GetFileName($Source)
    # Write-Host "  Checking `"$SourceName`""

    if (IsLoose($Source)) {
        ModCopy($Source)
    }
    elseif (IsBa2($Source)) {
        ModUnpack($Source)
    }
    elseif (IsFolder($Source)) {
        $SourcesSub = Get-ChildItem $Source -Exclude .*,_* | Sort-Object
        Foreach ($Sub in $SourcesSub) {
            if (IsLoose($Sub)) {
                ModCopy($Sub)
            }
            elseif (IsBa2($Sub)) {
                ModUnpack($Sub)
            }
        }
    }
    else {
        Write-Host "$Source does not look like a mod, please check..." -ForegroundColor $ColorWarn
    }
}

Write-Host "<-- Done Unpacking`n" -ForegroundColor $ColorNotice

# Normalize directory names

$Sources = Get-ChildItem $Unpacked -Include *
Foreach ($Source in $Sources) {
    $Name = [System.IO.Path]::GetFileName($Source)
    if ((IsLoose($Source)) -And ($Name -cne $Name.ToLower())) {
        Rename-Item -Path "$Source" -NewName "$($Source)_"
        Rename-Item -Path "$($Source)_" -NewName "$($Name.ToLower())"
    }
}

# Pack them up!

Write-Host "--> Packing mods to $($Data)..." -ForegroundColor $ColorNotice

# Strings need to be loaded loose

try {
    $UnpackedStrings = Resolve-Path "$Unpacked\strings" # will fail if no strings
    $HasStrings = $True
    Write-Host " > Copying loose strings" -ForegroundColor $ColorCommand
    Copy-Item -Path $UnpackedStrings -Destination $Data -Recurse -Force
} catch {
    Write-Verbose " > No loose strings"
}

# Textures need to be packed as DDS

try {
    $UnpackedTextures = Resolve-Path "$Unpacked\textures" # will fail if no textures
    $HasTextures = $True
    Remove-Item -ErrorAction Ignore -Force "$BundleTex" | Out-String | Write-Verbose
    Write-Host " > Packing textures" -ForegroundColor $ColorCommand
    & $Archive2 "$UnpackedTextures" -create="$BundleTex" -root="$Unpacked" -format=DDS | Out-String | Write-Verbose
} catch {
    Write-Verbose " > No textures"
}

# Everything else

Remove-Item -ErrorAction Ignore -Force "$Bundle" | Out-String | Write-Verbose

$Sources = Get-ChildItem $Unpacked -Exclude strings,textures | Sort-Object
Foreach ($Source in $Sources) {
    $Name = [System.IO.Path]::GetFileName($Source)
    Write-Host " > Packing $Name" -ForegroundColor $ColorCommand
}

# Give Archive2 a double-quoted list of directories to add, minus strings and textures
$Sources = '"{0}"' -f ($Sources -join '","')
& $Archive2 $Sources -create="$Bundle" -root="$Unpacked" -format=General | Out-String | Write-Verbose

Write-Host "<-- Done Packing`n" -ForegroundColor $ColorNotice

# Clean up if desired

if ($Clean) {
    Write-Host "--> Cleaning up" -ForegroundColor $ColorNotice
    Remove-Item -ErrorAction Ignore -Recurse -Force $Unpacked | Out-String | Write-Verbose
    Write-Host "<-- Ok`n" -ForegroundColor $ColorNotice
}

# Create a shortcut with the absolute paths so these settings are saved

if ($Save) {
    Write-Host "--> Saving a shortcut with these settings:" -ForegroundColor $ColorNotice
    Write-Host " > $($LnkFile -replace '\\+', '\')"

    $File = Resolve-Path "$PSScriptRoot\$($MyInvocation.MyCommand.Name)"
    $Arguments = @(
        "-ExecutionPolicy Bypass",
        "-File $File",
        "-Archive2 $Archive2Path",
        "-Mods $Mods",
        "-Game $Game",
        $(if ($Clean) {'-Clean'} else {''})
    ) -join ' '

    $WshShell = New-Object -comObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut($LnkFile)
    $Shortcut.TargetPath = "powershell.exe"
    $Shortcut.Arguments = $Arguments
    $Shortcut.Save()

    Write-Host "<-- Ok`n" -ForegroundColor $ColorNotice
}

# Be helpful!

$IniContent = ''
if (Test-Path $IniFile) {
    $IniContent = Get-Content $IniFile
}

$NeedsIni = !($IniContent -match 'Bunduru76_General')
$NeedsIniTextures = ($HasTextures -And !($IniContent -match 'Bunduru76_Textures'))
$NeedsIniStrings = ($HasStrings -And !($IniContent -match 'sResourceDataDirsFinal=STRINGS'))

if ($NeedsIni -Or $NeedsIniTextures -Or $NeedsIniStrings) {
    Write-Host "Looks like you need to add (or edit) this to your Fallout 76 config:" -ForegroundColor $ColorNotice
    Write-Host " > $IniFile"
    Write-Host ""

    $ToAdd = "[Archive]"
    $ToAdd += "`nsResourceArchive2List=Bunduru76_General.ba2"
    if ($HasTextures) {
        $ToAdd += ",Bunduru76_Textures.ba2"
    }
    if ($HasStrings) {
        $ToAdd += "`nsResourceDataDirsFinal=STRINGS\`nbInvalidateOlderFiles=1"
    }
    $ToAdd += "`n`n"

    Write-Host $ToAdd -ForegroundColor Yellow
    Set-Clipboard $ToAdd

    Write-Host "This has been copied to your clipboard, just paste it at the top (you may not need everything).`n" -ForegroundColor $ColorNotice


    $Response = Read-Host -Prompt 'Type "open" or "Y" to do it now or enter to exit'
    if ($Response -match 'open|y') {
        notepad.exe $IniFile
        Read-Host -Prompt "Press Enter to close"
    }
}

Write-Host "Done!" -ForegroundColor $ColorHead
