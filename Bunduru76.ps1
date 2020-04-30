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
.PARAMETER Interactive
    Prompt for all inputs.
.EXAMPLE
    C:\PS> .\path\to\bunduru76.ps1 -Archive2 .\path\to\Archive2\ -Mods .\path\to\Mods\ -Game .\path\to\Fallout76
    All parameters should be folders, Archive2 and Game parameters should be the directory that
    contains Archive2.exe and Fallout76.exe (and \Data) respectively.

    Recommended to put in a shortcut for ez-pz running
#>
[CmdletBinding()]
Param (
    [string]$Archive2,
    [string]$Mods,
    [string]$Game,
    [Alias('s')]
    [switch]$Save,
    [Alias('c')]
    [switch]$Clean,
    [Alias('i')]
    [switch]$Interactive
)

# Constants

$ColorHead = 'White'
$ColorCommand = 'Gray'
$ColorNotice = 'Cyan'
$ColorWarn = 'Red'
$ColorError = 'Red'
$Loosies = @('effects', 'interface', 'meshes', 'strings', 'terrain', 'textures')

# Helpers

function IsFolder($Path)
{
    return Test-Path -Path $Path -PathType Container
}

function IsFile($Path)
{
    return Test-Path -Path $Path -PathType Leaf
}

function IsBa2($Path)
{
    $Ext = [System.IO.Path]::GetExtension($Path)
    return $Ext -eq '.ba2'
}

function IsLoose($Path)
{
    $Name = [System.IO.Path]::GetFileName($Path)
    return ($Loosies.Contains($Name.ToLower())) -And (IsFolder($Path))
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

function GetFolder()
{
    Param (
        [string]$Description = $Null,
        [string]$Initial
    )

    [void] [System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms')
    $FolderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog -Property @{
        Description = $Description
        SelectedPath = if ($Initial) { Resolve-Path $Initial } else { Resolve-Path '.\' }
    }

    $Response = $FolderBrowser.ShowDialog((New-Object System.Windows.Forms.Form -Property @{
        TopMost = $true
    }))

    if ($Response -eq [Windows.Forms.DialogResult]::OK) {
        return $FolderBrowser.SelectedPath
    } else {
        return $False
    }
}

function GetConfirmation()
{
    Param (
        [string]$Title = 'something',
        [string]$Prompt = 'Are you sure you want to proceed?',
        [string[]]$Choices = @('&Yes', '&No'),
        [int]$Default = 0
    )

    $Response = $Host.UI.PromptForChoice($Title, $Prompt, $Choices, $Default)
    return $Response -eq 0
}

function ResolvePathOrFail($Path)
{
    if (Test-Path -Path $Path) {
        return Resolve-Path $Path
    }
    else {
        throw ''
    }
}


# Output some pre-amble

Write-Host "`n--==[ Fallout 76 Mod Bunduru ]==--`n" -ForegroundColor $ColorHead

Write-Debug "Parameters:"
$PSBoundParameters | Format-Table | Out-String | Write-Debug


# If we are missing any paths, we will need to ask nicely for them

$SelectArchive2 = $Interactive -Or (-Not $PSBoundParameters.ContainsKey('Archive2'))
$SelectMods = $Interactive -Or (-Not $PSBoundParameters.ContainsKey('Mods'))
$SelectGame = $Interactive -Or (-Not $PSBoundParameters.ContainsKey('Game'))

if ($SelectArchive2 -Or $SelectMods -Or $SelectGame) {
    Write-Host '--> Interactive mode, please choose your folders...' -ForegroundColor $ColorNotice

    if ($SelectArchive2) {
        $Archive2 = GetFolder -Description 'Please select folder containing Archive2.exe' -Initial $Archive2
    }
    Write-Host "  Archive2   > $Archive2"

    if ($SelectMods) {
        $Mods = GetFolder -Description 'Please select Mods folder' -Initial $Mods
    }
    Write-Host "  Mods       > $Mods"

    if ($SelectGame) {
        $Game = GetFolder -Description 'Please select Fallout 76 folder' -Initial $Game
    }
    Write-Host "  Fallout 76 > $Game"

    Write-Host "<-- Ok`n" -ForegroundColor $ColorNotice
    $Interactive = $True # So the rest of the script knows a dialog was opened
}


# Check and normalize paths.

try {
    $Archive2Path = ResolvePathOrFail $Archive2
    $Archive2 = ResolvePathOrFail "$Archive2Path\Archive2.exe"

    # Make sure Archive2 is really Archive2
    $Output = (& $Archive2 -?) | Out-String
    if (-Not ($Output -match 'Archive2 <archive, files\/folders>')) { throw '' }
} catch {
    Write-Host "Archive2.exe path does not appear to be valid, please check your paths."
    Exit 1
}

try {
    $Mods = ResolvePathOrFail $Mods
} catch {
    Write-Host "Mod folder does not appear valid, please check your paths."
    Exit 1
}

try {
    $Game = ResolvePathOrFail $Game
    $Data = ResolvePathOrFail "$Game\Data\"
} catch {
    Write-Host "Fallout 76 Data folder does not appear to be valid, please check your paths."
    Exit 1
}


# Computed values we need for later

$Unpacked = "$Mods\.unpacked\"
$Bundle = "$Data\Bunduru76_General.ba2"
$BundleTex = "$Data\Bunduru76_Textures.ba2"

$LnkFile = "$($Mods)\Bunduru76.lnk"
$IniFile = "$([Environment]::GetFolderPath("MyDocuments"))\My Games\Fallout 76\Fallout76Custom.ini"

$HasStrings = $False
$HasTextures = $False


# All good probably. Let's do this!

Write-Host " Ready to go with the following paths:"
Write-Host "  Archive2   > $Archive2"
Write-Host "  Mods       > $Mods"
Write-Verbose "  Unpacked   > $Unpacked"
Write-Host "  Fallout 76 > $Game"
Write-Verbose "  Data       > $Data"
Write-Host ""


# Clear staging folder

Remove-Item -ErrorAction Ignore -Recurse -Force $Unpacked | Out-String | Write-Verbose
New-Item -ItemType Directory -Force -Path $Unpacked | Out-String | Write-Verbose
$Unpacked = Resolve-Path $Unpacked


# Loop through each source, look for special directories or ba2, put them all in the staging folder

Write-Host "--> Getting mods from $($Mods)..." -ForegroundColor $ColorNotice

$Sources = Get-ChildItem $Mods -Exclude .*,_* | Sort-Object
$Sources | Format-Table | Out-String | Write-Debug
foreach ($Source in $Sources) {
    if (IsLoose($Source)) {
        ModCopy($Source)
    }
    elseif (IsBa2($Source)) {
        ModUnpack($Source)
    }
    elseif (IsFolder($Source)) {
        $SourcesSub = Get-ChildItem $Source -Exclude .*,_* | Sort-Object
        $SourcesSub | Format-Table | Out-String | Write-Debug
        foreach ($Sub in $SourcesSub) {
            if (IsLoose($Sub)) {
                ModCopy($Sub)
            }
            elseif (IsBa2($Sub)) {
                ModUnpack($Sub)
            }
        }
    }
    else {
        Write-Verbose "$Source does not look like a mod, skipping..."
    }
}

Write-Host "<-- Done Unpacking`n" -ForegroundColor $ColorNotice


# Normalize directory names

$Sources = Get-ChildItem $Unpacked -Include *
foreach ($Source in $Sources) {
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
    $UnpackedStrings = ResolvePathOrFail "$Unpacked\strings"
    $HasStrings = $True
    Write-Host " > Copying loose strings" -ForegroundColor $ColorCommand
    Copy-Item -Path $UnpackedStrings -Destination $Data -Recurse -Force
} catch {
    Write-Verbose " > No loose strings"
}

# Textures need to be packed as DDS

try {
    $UnpackedTextures = ResolvePathOrFail "$Unpacked\textures"
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
foreach ($Source in $Sources) {
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

if ($Interactive -And (-Not $Save)) {
    # Since it was interactive mode, ask the user if they want a shortbutt
    $Save = GetConfirmation -Title 'Save Shortcut?' -Prompt 'Would you like to save a shortcut in your mods folder to make this bundle easier next time?'
}

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


# Give helpful advice

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
    if ($Response -match '^open|y') {
        notepad.exe $IniFile
        Read-Host -Prompt "Press Enter to close"
    }
}

Write-Host "Done!" -ForegroundColor $ColorHead
