<#
.SYNOPSIS
    Compare hashes from MDT Deploymentshare

.DESCRIPTION
   hashes are compared against exported digests values to key files in the deploymentshare
   Designed for OEM Media deployments for validating content use LTIHashCheckUI.ps1 to create hashes

.NOTES
    Author		: Dick Tracy II <richard.tracy@microsoft.com>
	Source	    : https://github.com/PowerShellCrack/OSDHashChecker
    Version		: 1.3.1
    #Requires -Version 3.0

.PARAMETER WorkingPath
    MANDATORY. File path to Deploymentshare directory

.PARAMETER CompareType
    OPTIONS: StoredHash|ExportedHash
    DEFAULT StoredHash
    StoredHash  --> Uses stored hash digest as custom properties within the customesettings.ini to compare with deploymentshare
    ExportedHash --> Uses exported hashes in clixml file at root of deployment share to compare with deploymentshare

.PARAMETER TaskSequenceID
    STRING. Specifies the TS.xml to compare hash against
    NOTE: Not manadatory. If not specifiecd, script will attempt to use TaskSequenceID proeprty value in the default section of customesettings.ini
    If none exist, script will end.

.PARAMETER ExcludeFiles
    STRING ARRAY. Specifies the list of files to exlude from file hashing process.
    These files can interfere with hashing process because they are actively be changed.

.PARAMETER Title
    STRING. Used only with UI, this will set the title to display

.PARAMETER ShowStatusUI
    SWITCH. Enables the UI to display status.

.EXAMPLE
    .\LTIHashCheckUI.ps1 -WorkingPath "C:\DeploymentShare" -CompareType StoredHash
    -----------
    Description
    Compares the hash values in properties from the C:\DeploymentShare\Control\customesettings.ini with deploymentshare processed hashes
    -----------
    Example
    [Settings]
    Priority=Default
    Properties=Hash_DeployFolders,Hash_DeployFiles,Hash_DeployTS,Hash_DeployWIM

    [Default]
    Hash_DeployFiles=06A5FDAD592285DFDE057451189C53724236A2DDFC324D54696F11DA544B419F
    Hash_DeployFolders=FD454A0AB02E395517EE414530E2F1F32FD43EFF00029B1BB4C10BA13E60337C
    Hash_DeployTS=18E32E3E2C925A57B5DBA1B9B0A35D55CFA97F6F549D33FF2FA80DCF0A0799BB
    Hash_DeployWIM=05F0F08FAAC2A7DAC574143A7A415197207F68B8636561018DB3A0C5C5FBE983

.EXAMPLE
    .\LTIHashCheckUI.ps1 -WorkingPath "C:\DeploymentShare" -CompareType ExportedHash
    -----------
    Description
    Uses hash values in these files located in C:\DeploymentShare

    Content_TSHash.xml
    Content_WIMHash.xml
    Content_FileList.xml
    Content_FolderList.xml

.EXAMPLE
    .\LTIHashCheckUI.ps1 -WorkingPath "C:\DeploymentShare" -CompareType StoredHash -Title 'Validate Media' -ShowStatusUI
    -----------
    Description
    Compares the hash values in properties from the C:\DeploymentShare\Control\customesettings.ini with deploymentshare processed hashes
    while displaying a status UI with 'Validate Media' as title. Script attempts finds property TaskSequenceID in customesettings.ini

.EXAMPLE
    .\LTIHashCheckUI.ps1 -WorkingPath "C:\DeploymentShare" -Title 'Validate Media' -TaskSequenceID WIN10_EUH -ShowStatusUI
    -----------
    Description
    Compares the hash values in properties from the C:\DeploymentShare\Control\customesettings.ini (by default) with deploymentshare processed hashes
    while displaying a status UI with 'Validate Media' as title. TaskSequence is specified and will use the ID to find the attached operating system file

.LINK
    LTIHashStoreUI.ps1
#>
[CmdletBinding()]
Param
(
    # Specifies the path to the path that will be processed.
    [Parameter(Mandatory = $true, Position=0)]
    [ValidateNotNullOrEmpty()]
    [String]$WorkingPath,

    [Parameter(Mandatory = $false, Position=1)]
    [ValidateSet("StoredHash","ExportedHash")]
    [String]$CompareType = "StoredHash",

    [Parameter(Mandatory = $false, Position=2)]
    [String]$TaskSequenceID,

    [string[]]$ExcludeFiles = ('CustomSettings.ini','Audit.log','Autorun.inf'),

    [String]$Title,

    [switch]$ShowStatusUI
)

#*=============================================
##* Runtime Function - REQUIRED
##*=============================================

#region FUNCTION: Check if running in ISE
Function Test-IsISE {
    # try...catch accounts for:
    # Set-StrictMode -Version latest
    try {
        return ($null -ne $psISE);
    }
    catch {
        return $false;
    }
}
#endregion

#region FUNCTION: Check if running in Visual Studio Code
Function Test-VSCode{
    if($env:TERM_PROGRAM -eq 'vscode') {
        return $true;
    }
    Else{
        return $false;
    }
}
#endregion

#region FUNCTION: Find script path for either ISE or console
Function Get-ScriptPath {
    <#
        .SYNOPSIS
            Finds the current script path even in ISE or VSC
        .LINK
            Test-VSCode
            Test-IsISE
    #>
    param(
        [switch]$Parent
    )

    Begin{}
    Process{
        if ($PSScriptRoot -eq "")
        {
            if (Test-IsISE)
            {
                $ScriptPath = $psISE.CurrentFile.FullPath
            }
            elseif(Test-VSCode){
                $context = $psEditor.GetEditorContext()
                $ScriptPath = $context.CurrentFile.Path
            }
        }
        else
        {
            $ScriptPath = $PSCommandPath
        }
    }
    End{

        If($Parent){
            Split-Path $ScriptPath -Parent
        }Else{
            $ScriptPath
        }
    }

}
#endregion
##*=============================================
##* VARIABLE DECLARATION
##*=============================================
If ($PSBoundParameters['Debug']) {$DebugPreference = 'Continue'}
If ($PSBoundParameters['Verbose']) {$VerbosePreference = 'Continue'}
#region VARIABLES: Building paths & values
# Use function to get paths because Powershell ISE & other editors have differnt results
[string]$scriptPath = Get-ScriptPath
[string]$scriptName = [IO.Path]::GetFileNameWithoutExtension($scriptPath)
[string]$scriptFileName = Split-Path -Path $scriptPath -Leaf
[string]$scriptRoot = Split-Path -Path $scriptPath -Parent
[string]$invokingScript = (Get-Variable -Name 'MyInvocation').Value.ScriptName

[string]$FunctionPath = Join-Path -Path $scriptRoot -ChildPath 'Functions'
[string]$ResourcePath = Join-Path -Path $scriptRoot -ChildPath 'Resources'
[string]$XAMLPath = Join-Path -Path $ResourcePath -ChildPath 'StatusScreen.xaml'
#*=============================================
##* External Functions
##*=============================================
#Load functions from external files
. "$FunctionPath\Environments.ps1"
. "$FunctionPath\Hashing.ps1"
. "$FunctionPath\IniContent.ps1"
. "$FunctionPath\Logging.ps1"

# Make PowerShell Disappear in WINPE
If(Test-WinPE){
    $windowcode = '[DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);'
    $asyncwindow = Add-Type -MemberDefinition $windowcode -name Win32ShowWindowAsync -namespace Win32Functions -PassThru
    $null = $asyncwindow::ShowWindowAsync((Get-Process -PID $pid).MainWindowHandle, 0)
}
#endregion

#grab all Show-ProgressStatus commands in script and count them
$script:Maxsteps = ([System.Management.Automation.PsParser]::Tokenize((Get-Content $scriptPath), [ref]$null) | Where-Object { $_.Type -eq 'Command' -and $_.Content -eq 'Invoke-StatusUpdate' }).Count
#set counter to one
$stepCounter = 1
#=======================================================
# LOAD ASSEMBLIES
#=======================================================
[System.Reflection.Assembly]::LoadWithPartialName('WindowsFormsIntegration') | out-null # Call the EnableModelessKeyboardInterop
If(Test-WinPE -or Test-IsISE){[System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Application') | out-null} #Encapsulates a Windows Presentation Foundation application.
[System.Reflection.Assembly]::LoadWithPartialName('presentationframework') | out-null
[System.Reflection.Assembly]::LoadWithPartialName('PresentationCore') | out-null

#=======================================================
# Splash Screen
#=======================================================
function Start-UIStatusScreen
{
    #launch the modal window with the progressbar
    $Script:Pwshell.Runspace = $Script:runspace
    $Script:Handle = $Script:Pwshell.BeginInvoke()

    # we need to wait that all elements are loaded
    While (!($Global:StatusScreen.Window.IsInitialized)) {
        Start-Sleep -Milliseconds 500
    }
}

function Close-UIStatusScreen
{
    #Invokes UI to close
    $Global:StatusScreen.Window.Dispatcher.Invoke("Normal",[action]{$Global:StatusScreen.Window.close()})
    $Script:Pwshell.EndInvoke($Script:Handle) | Out-Null

    #Closes and Disposes the UI objects/threads
    $Script:Pwshell.Runspace.Close()
	$Script:Pwshell.Dispose()
}

Function Update-UIProgress{
    [CmdletBinding()]
    param(
        [Parameter(Position=0,Mandatory=$true)]
        [String] $Label,

        [Parameter(Position=1)]
        [int] $Progress,

        [Parameter(Position=2)]
        [switch] $Indeterminate,

        [string] $Color = "LightGreen"
    )

    if(!$Indeterminate){
        if(($Progress -ge 0) -and ($Progress -lt 100)){
	        $Global:StatusScreen.ProgressBar.Dispatcher.Invoke("Normal",[action]{
			        $Global:StatusScreen.ProgressBar.IsIndeterminate = $False
			        $Global:StatusScreen.ProgressBar.Value= $progress
			        $Global:StatusScreen.ProgressBar.Foreground=$Color
			        $Global:StatusScreen.ProgressText.Text= $label
			        $Global:StatusScreen.PercentageText.Text= ('' + $progress+'%')
            })
        }
        elseif($progress -eq 100){
            $Global:StatusScreen.ProgressBar.Dispatcher.Invoke("Normal",[action]{
			        $Global:StatusScreen.ProgressBar.IsIndeterminate = $False
			        $Global:StatusScreen.ProgressBar.Value= $progress
			        $Global:StatusScreen.ProgressBar.Foreground=$Color
			        $Global:StatusScreen.ProgressText.Text= $label
			        $Global:StatusScreen.PercentageText.Text= ('' + $progress+'%')
            })
        }
        else{Write-Warning "Out of range"}
    }
    else{
    $Global:StatusScreen.ProgressBar.Dispatcher.Invoke("Normal",[action]{
			$Global:StatusScreen.ProgressBar.IsIndeterminate = $True
			$Global:StatusScreen.ProgressBar.Foreground=$Color
			$Global:StatusScreen.ProgressText.Text= $label
            $Global:StatusScreen.PercentageText.Text=' '
      })
    }
}

Function Update-UIElementProperty{
    [CmdletBinding()]
    param(
        [Parameter(Position=0,Mandatory=$true)]
        [String]$ElementName,

        [Parameter(Position=1,Mandatory=$true)]
        [ValidateSet('Visibility','Text','Content','Foreground','Background','IsReadOnly','IsEnabled','Fill','BorderThickness','BorderBrush')]
        [String]$Property,

        [Parameter(Position=3,Mandatory=$true)]
        [String]$Value
    )

    $Global:StatusScreen.$ElementName.Dispatcher.Invoke("Normal",[action]{
        $Global:StatusScreen.$ElementName.$Property=$Value
    })
}

Function Invoke-UICountdown
{
    [CmdletBinding()]
    param(
        [Parameter(Position=0,Mandatory=$true)]
        [int]$CountDown,
        [String]$TextElement,
        [scriptblock]$Action
    )

    #detemine supported elements and the property to update
    Switch($Global:StatusScreen.$TextElement.GetType().Name){
        'Button' {$property = 'Content'}
        'Label' {$property = 'Content'}
        'TextBox' {$property = 'Text'}
        'TextBlock' {$property = 'Text'}
        default {$property = 'Text'}
    }

    #ensure element is visable
    Update-UIElementProperty -ElementName $TextElement -Property Visibility -Value 'Visible'

    #display the elements countdown value
    Update-UIElementProperty -ElementName $TextElement -Property $property -Value $CountDown

    while ($CountDown -ge 0)
    {
        #update the elements countdown value
        Update-UIElementProperty -ElementName $TextElement -Property $property -Value $CountDown
        start-sleep 1
        $CountDown -= 1
    }

    #invoke an action if specified
    If($Action){
        Invoke-Command $Action
    }
}



# build a hash table with locale data to pass to runspace
$Global:StatusScreen = [hashtable]::Synchronized(@{})
$Global:StatusScreen.XAML = $XAMLPath
$Global:StatusScreen.Title = $Title
$Global:StatusScreen.IsPE = Test-WinPE
$Global:StatusScreen.IsISE = Test-IsISE
$Global:StatusScreen.IsVSC = Test-VSCode
$Global:StatusScreen.IsTSEnv = $Script:tsenv
#build runspace
$Script:runspace = [runspacefactory]::CreateRunspace()
$Script:runspace.ApartmentState = "STA"
$Script:runspace.ThreadOptions = "ReuseThread"
$Script:runspace.Open()
$Script:runspace.SessionStateProxy.SetVariable("StatusScreen",$Global:StatusScreen)
$Script:Pwshell = [PowerShell]::Create()

#Create a scripblock with variables from hashtable
$Script:Pwshell.AddScript({
    [string]$XAMLFile = $Global:StatusScreen.XAML
    [string]$HeaderTitle = $Global:StatusScreen.Title
    [Boolean]$RunningInPE = $Global:StatusScreen.IsPE
    [Boolean]$RunningInISE = $Global:StatusScreen.IsISE
    [Boolean]$RunningInVSC = $Global:StatusScreen.IsVSC
    [Boolean]$RunningInTS = $Global:StatusScreen.IsTSEnv

    $XAML = (get-content $XAMLFile -ReadCount 0) -replace 'mc:Ignorable="d"','' -replace "x:N",'N' -replace '^<Win.*', '<Window' -replace 'Click=".*','/>' -replace 'Demo',''
    $reader = New-Object System.Xml.XmlNodeReader ([xml]$XAML)
    try { $Global:StatusScreen.Window = [Windows.Markup.XamlReader]::Load($reader) }
    catch
    {
        $Global:StatusScreen.critError = $true
        $ErrorMessage = $_.Exception.Message
        Write-Host "Unable to load Windows.Markup.XamlReader for $XAMLFile. Some possible causes for this problem include:
        - .NET Framework is missing
        - PowerShell must be launched with PowerShell -sta
        - invalid XAML code was encountered
        - The error message was [$ErrorMessage]" -ForegroundColor White -BackgroundColor Red
        Exit
    }

    #Closes UI objects and exits (within runspace)
    Function Close-UIStatusScreen
    {
        if ($Global:StatusScreen.hadCritError) { Write-Host -Message "Background thread had a critical error" -ForegroundColor red }
        #if runspace has not errored Dispose the UI
        if (!($Global:StatusScreen.isClosing)) { Stop-UIStatusScreen }
    }

    #Disposes UI objects and exits (within runspace)
    Function Stop-UIStatusScreen
    {
        $Global:StatusScreen.Window.Close()
        $Script:runspace.Close()
        $Script:runspace.Dispose()
    }

    $Global:StatusScreen.Window.Add_Loaded({ $Global:StatusScreen.isLoaded = $True })
	$Global:StatusScreen.Window.Add_Closing({ $Global:StatusScreen.isClosing = $True; Close-UIStatusScreen })
	$Global:StatusScreen.Window.Add_Closed({ $Global:StatusScreen.isClosed = $True })

    $Global:StatusScreen.Header = $Global:StatusScreen.window.FindName("lblHeader")
    $Global:StatusScreen.ProgressBar = $Global:StatusScreen.window.FindName("ProgressBar")
    $Global:StatusScreen.ProgressText = $Global:StatusScreen.window.FindName("txtProgress")
    $Global:StatusScreen.PercentageText = $Global:StatusScreen.window.FindName("txtPercentage")
    $Global:StatusScreen.Hash_DeployWIM_Text = $Global:StatusScreen.window.FindName("txtHash01")
    $Global:StatusScreen.Hash_DeployWIM_Alert = $Global:StatusScreen.window.FindName("imgHash01_Alert")
    $Global:StatusScreen.Hash_DeployWIM_Check = $Global:StatusScreen.window.FindName("imgHash01_Check")
    $Global:StatusScreen.Hash_DeployTS_Text = $Global:StatusScreen.window.FindName("txtHash02")
    $Global:StatusScreen.Hash_DeployTS_Alert = $Global:StatusScreen.window.FindName("imgHash02_Alert")
    $Global:StatusScreen.Hash_DeployTS_Check = $Global:StatusScreen.window.FindName("imgHash02_Check")
    $Global:StatusScreen.Hash_DeployFiles_Text = $Global:StatusScreen.window.FindName("txtHash03")
    $Global:StatusScreen.Hash_DeployFiles_Alert = $Global:StatusScreen.window.FindName("imgHash03_Alert")
    $Global:StatusScreen.Hash_DeployFiles_Check = $Global:StatusScreen.window.FindName("imgHash03_Check")
    $Global:StatusScreen.Hash_DeployFolders_Text = $Global:StatusScreen.window.FindName("txtHash04")
    $Global:StatusScreen.Hash_DeployFolders_Alert = $Global:StatusScreen.window.FindName("imgHash04_Alert")
    $Global:StatusScreen.Hash_DeployFolders_Check = $Global:StatusScreen.window.FindName("imgHash04_Check")
    $Global:StatusScreen.CloseWindow = $Global:StatusScreen.window.FindName("CloseWindow")
    $Global:StatusScreen.Shutdown = $Global:StatusScreen.window.FindName("Shutdown")

    If($HeaderTitle){
        $Global:StatusScreen.Header.Content = $HeaderTitle
    }

    #hide all icons first
    $Global:StatusScreen.Hash_DeployWIM_Alert.Visibility='Hidden'
    $Global:StatusScreen.Hash_DeployWIM_Check.Visibility='Hidden'
    $Global:StatusScreen.Hash_DeployTS_Alert.Visibility='Hidden'
    $Global:StatusScreen.Hash_DeployTS_Check.Visibility='Hidden'
    $Global:StatusScreen.Hash_DeployFiles_Alert.Visibility='Hidden'
    $Global:StatusScreen.Hash_DeployFiles_Check.Visibility='Hidden'
    $Global:StatusScreen.Hash_DeployFolders_Alert.Visibility='Hidden'
    $Global:StatusScreen.Hash_DeployFolders_Check.Visibility='Hidden'
    #hide button
    $Global:StatusScreen.CloseWindow.Visibility='Hidden'
    $Global:StatusScreen.Shutdown.Visibility='Hidden'

    If($RunningInISE -or $RunningInVSC){
        $Global:StatusScreen.CloseWindow.Visibility='Visible'
    }

    #action for button
    $Global:StatusScreen.CloseWindow.Dispatcher.Invoke([action]{
        $Global:StatusScreen.CloseWindow.Add_Click({
            $Global:StatusScreen.Window.Dispatcher.Invoke([action]{ Close-UIStatusScreen })
            #$Script:Pwshell.EndInvoke($Handle) | Out-Null
            #$Script:runspace.Close() | Out-Null
        })
    })

    #action for button
    $Global:StatusScreen.Shutdown.Dispatcher.Invoke([action]{
        $Global:StatusScreen.Shutdown.Add_Click({
            $Global:StatusScreen.Window.Dispatcher.Invoke([action]{ Close-UIStatusScreen })
            #$Script:Pwshell.EndInvoke($Handle) | Out-Null
            #$Script:runspace.Close() | Out-Null
            If($RunningInPE){Start-Process Wpeutil -ArgumentList 'Shutdown' -PassThru -Wait | Out-Null}
        })
    })

    #make sure this display on top of every window
    $Global:StatusScreen.window.Topmost = $true
    #add option to allow window in front if ESC is hit (Only if not in PE)
    If($RunningInPE -eq $false){
        $Global:StatusScreen.Window.Add_KeyDown({ if ($_.Key -match 'Esc') { $Global:StatusScreen.window.Topmost = $false } })
    }

    $Global:StatusScreen.Window.ShowDialog()
    $Script:runspace.Close()
    $Script:runspace.Dispose()
    $Global:StatusScreen.Error = $Error
}) | Out-Null

#only run splash screen if enabled & testmode is disabled
Invoke-StatusUpdate -Message ("Comparing Hashes, Please wait...") -UpdateUI:$ShowStatusUI -Outhost -ShowProgress

#=======================================================
# GET INFO
#=======================================================
#verifing workingpath before continuing
If( !(Test-Path $("filesystem::$workingpath")) ){
    Invoke-StatusUpdate -Message ("Working path [{0}] not found or is inaccessible." -f $workingpath) `
                -Step 1 -MaxStep 1 -UpdateUI:$ShowStatusUI `
                -UpdateTextElement @{'Hash_DeployWIM_Text'="Invalid content path"} `
                -HideUIElement 'CloseWindow' `
                -ShowUIElement 'Shutdown' -Outhost -ShowProgress -DisplayColor Red
    Exit -1
}
Else{
    #[string]$WorkingPath = 'Z:\DeployNMCI_OEM\Content\Deploy'
    #make sure there is no [\] after working path
    $WorkingPath = $WorkingPath -replace '[\\/]?[\\/]$'
}

#Set the location for the files and folder to export
[string]$ExportedTSHash = Join-Path -Path $WorkingPath -ChildPath 'Content_TSHash.xml'
[string]$ExportedWIMHash = Join-Path -Path $WorkingPath -ChildPath 'Content_WIMHash.xml'
[string]$ExportedFileList = Join-Path -Path $WorkingPath -ChildPath 'Content_FileList.xml'
[string]$ExportedFolderList = Join-Path -Path $WorkingPath -ChildPath 'Content_FolderList.xml'

#get the MDT Control folder and customsettings.ini
[string]$ControlFolder = Join-Path -Path $WorkingPath -ChildPath 'Control'
[string]$CSINI = Join-Path -Path $ControlFolder -ChildPath 'CustomSettings.ini'
#grab all properties and values in CustomSetting.ini
$FileContent = Get-IniContent -FilePath $CSINI -IgnoreComments

#if parameter specified, use that instead of searching cs.ini
If($TaskSequenceID){
    $DefaultTsId = $TaskSequenceID
}
Else{
    #grab the default TaskSequence ID specified in the CustomSetting.ini
    $DefaultTsId = $FileContent["Default"]["TaskSequenceID"]
}

#if the TS does not exist, assume there is only one and use that
If(!$DefaultTsId){
    Invoke-StatusUpdate -Message ("TaskSequence IS was not found or specified.") `
                -Step 1 -MaxStep 1 -UpdateUI:$ShowStatusUI `
                -UpdateTextElement @{'Hash_DeployWIM_Text'="TaskSequence ID not found"} `
                -HideUIElement 'CloseWindow' `
                -ShowUIElement 'Shutdown' -Outhost -ShowProgress -DisplayColor Red
    Exit -1
}

#Name corresponds with folder name, get the current task sequence xml
[string]$TsFolder = Join-Path -Path $ControlFolder -ChildPath $DefaultTsId
[string]$TsXmlFile = Join-Path -Path $TsFolder -ChildPath "TS.xml"

#check to ensure  TS.xml does exit
If(!(Test-Path $TsXmlFile)){
    Invoke-StatusUpdate -Message ("TaskSequence XML file [{0}] is missing" -f $TsXmlFile) -Step 1 -MaxStep 1 -UpdateUI:$ShowStatusUI `
                -UpdateTextElement @{'Hash_DeployWIM_Text'=("TaskSequence ID missing [{0}]" -f $DefaultTsId)} `
                -HideUIElement 'CloseWindow' `
                -ShowUIElement 'Shutdown' -Outhost -ShowProgress -DisplayColor Red
    Exit -1
}

#parse the XML to get the Operating system image being deployed
[XML]$TS = Get-Content $TsXmlFile -ReadCount 0
#grab guid of Operating system
$OsGuid = (($TS.sequence.globalVarList | Select -ExpandProperty variable) | Where-Object {$_.name -eq "OSGUID"} | Select-Object -First 1).'#text'

#Get the directory fo the Operating system file based on GUID
[string]$OsXmlFile = Join-Path -Path $ControlFolder -ChildPath 'OperatingSystems.xml'
[XML]$Os = Get-Content $OsXmlFile -ReadCount 0
$OsImagePath = ($Os.oss.os | Where guid -eq $OsGuid | Select -ExpandProperty ImageFile) -replace '^.',$WorkingPath
$OsImageFile = Get-Item $OsImagePath

#change the verb based on action
Switch($CompareType){
    'ExportedHash'  {$MsgPresentVerb = 'Exporting';$MsgPastVerb = 'Exported'}
    'StoredHash'    {$MsgPresentVerb = 'Hashing';$MsgPastVerb = 'Hashed'}
}

#=======================================================
# START HASHING
#=======================================================
#build Hashes into a HashTable for comparison
$DeployHashes = @{}

#start item count
$i = 0
#Find the WIM or SWM's and get hash
#----------------------------------
If($OsImageFile.Extension -eq '.swm'){
    #loop through all SWM files
    $AllSwmFiles = Get-ChildItem -Path (Split-Path $OsImageFile -Parent) -Filter '*.swm'
    #TEST $AllSwmFiles = Get-ChildItem -Path ((Split-Path $OsImageFile -Parent) + '_split') -Filter '*.swm'

    #Determine percentage increment: device 100% with start total item count (swm count + 3 file hashes + 1 action):
    $pi=[math]::Round(100 - ((($AllSwmFiles.Count + 4)-1)/($AllSwmFiles.Count + 4) * 100),2 )

    #the first SWM doesn't have a incemented number in basename, it the original
    $FirstSwmLength = ($AllSwmFiles.BaseName).GetEnumerator().length  | Measure -Minimum | Select -ExpandProperty minimum
    $FirstSwm = $AllSwmFiles.BaseName | Where length -eq $FirstSwmLength
    do {
        #increment item count by each swm processed
        $i++

        #make sure you grab the correct file to process
        If($i -eq 1){
            $SWMFile = $AllSwmFiles | Where BaseName -eq $FirstSwm
        }
        Else{
            $SWMFile = $AllSwmFiles | Where {($_.BaseName -ne $FirstSwm) -and ($_.BaseName -match ".?$i$")}
        }


        Invoke-StatusUpdate -Message ("Processing SWM file [{0} of {1}]. Hashing [{2}]. This can take awhile..." -f $i,$AllSwmFiles.count,$SWMFile) `
                -Step ($stepCounter++) -MaxStep $script:Maxsteps -UpdateUI:$ShowStatusUI `
                -UpdateTextElement @{'Hash_DeployWIM_Text'='Hashing SWM File...'} `
                -UpdateBorderElement @{'Hash_DeployWIM_Text'='1'} `
                -Outhost -ShowProgress

        #$Hash_DeploySWM = ($SWMFile | Get-FileHash).Hash
        Measure-Command { $Hash_DeploySWM = (Get-ChildItem $OsImagePath | Get-FileHash).Hash } -OutVariable Measured | Out-Null

        #filter the measure to just minutes and second
        $Measured = $Measured | select @{n="time";e={$_.Minutes,"Minutes",$_.Seconds,"Seconds" -join " "}}
        #dynamically build variable with value
        Set-Variable ('Hash_DeploySWM' + ('{0:d3}' -f $i)) -Value $Hash_DeploySWM
        #apply variable and value to hashtable
        $DeployHashes.Add('Hash_DeploySWM' + ('{0:d3}' -f $i),$Hash_DeploySWM)

    } until ($i -eq $AllSwmFiles.count)

    Invoke-StatusUpdate -Message ('Completed in [{0}]' -f $Measured.Time) -Step ($stepCounter++) -MaxStep $script:Maxsteps -UpdateUI:$ShowStatusUI `
                -UpdateTextElement @{'Hash_DeployWIM_Text'=('{0} [{1}]' -f $MsgPastVerb,$OsImageFile.Name,$Measured.Time)} `
                -UpdateBorderElement @{'Hash_DeployWIM_Text'='1'} `
                -Outhost -ShowProgress -DisplayColor Green

}
Else
{
    #start total item count to 5 (1 wim + 3 file hashes + 1 action):
    $s = 5
    #calculate percentage increments
    $pi=[math]::Round(100 - (($s-1)/$s * 100),2)
    #increment item
    $i++

    Invoke-StatusUpdate -Message ("Processing WIM file [{0}]. This can take awhile..." -f $OsImagePath) -Step ($stepCounter++) -MaxStep $script:Maxsteps -UpdateUI:$ShowStatusUI `
                -UpdateTextElement @{'Hash_DeployWIM_Text'='Hashing WIM File...'} `
                -Outhost -ShowProgress

    Measure-Command {
        #zero out job second counts
        $j=0
        Start-job -ScriptBlock { (Get-ChildItem $args[0] | Get-FileHash).Hash } -Name "WIMHasher" -ArgumentList $OsImagePath | Out-Null
        do {
            #add a dot and increment job second count by 1
            write-host "." -NoNewline;$j++;Start-Sleep 5
            If($j -gt 100){$j = 100}
            If($ShowStatusUI){
                Update-UIProgress -Label ("[{0} of {1}] :: Hashing [{2}]..." -f $i,$s,$OsImageFile.Name) -Progress $j
            }
        } until ((Get-job -Name WIMHasher).State -eq 'Completed')
        #catch the job output in a variable, then remove the job
        $Hash_DeployWIM = get-job -Name WIMHasher | Receive-Job
        Get-Job -Name WIMHasher | Remove-job | Out-Null
        #Write-Host $Hash_DeployWIM
    } -OutVariable Measured | Out-Null

    #filter the measure to just minutes and second
    $Measured = $Measured | select @{n="time";e={$_.Minutes,"Minutes",$_.Seconds,"Seconds" -join " "}}
    #apply variable and value to hashtable
    $DeployHashes.Add('Hash_DeployWIM',$Hash_DeployWIM)

    Invoke-StatusUpdate -Message ('Completed in [{0}]' -f $Measured.Time) -Step ($stepCounter++) -MaxStep $script:Maxsteps -UpdateUI:$ShowStatusUI `
                -UpdateTextElement @{'Hash_DeployWIM_Text'=('{0} [{1}]' -f $MsgPastVerb,$OsImageFile.Name,$Measured.Time)} `
                -UpdateBorderElement @{'Hash_DeployWIM_Text'='1'} `
                -Outhost -ShowProgress -DisplayColor Green
}


#getting hash of Tasksequence
#----------------------------------
$i++
Invoke-StatusUpdate -Message ("[{0} of {1}] ::  Getting hash of Tasksequence file [{2}]. Please wait..." -f $i,$s,$TSXmlFile) `
                -Step ($stepCounter++) -MaxStep $script:Maxsteps -UpdateUI:$ShowStatusUI `
                -UpdateTextElement @{'Hash_DeployTS_Text'='Hashing TaskSequence...'} `
                -Outhost -ShowProgress

Measure-Command { $Hash_DeployTS = (Get-ChildItem $TSXmlFile | Get-FileHash).Hash } -OutVariable Measured | Out-Null
#filter the measure to just minutes and second
$Measured = $Measured | select @{n="time";e={$_.Minutes,"Minutes",$_.Seconds,"Seconds" -join " "}}
#apply variable and value to hashtable
$DeployHashes.Add('Hash_DeployTS',$Hash_DeployTS)

Invoke-StatusUpdate -Message ('Completed in [{0}]' -f $Measured.Time) -Step ($stepCounter++) -MaxStep $script:Maxsteps -UpdateUI:$ShowStatusUI `
                -UpdateTextElement @{'Hash_DeployTS_Text'=('{0} [{1}] TaskSequence' -f $MsgPastVerb,$DefaultTsId,$Measured.Time)} `
                -UpdateBorderElement @{'Hash_DeployTS_Text'='1'} `
                -Outhost -ShowProgress -DisplayColor Green

 #getting just the files names
#----------------------------------
$i++
Measure-Command {
    If($StoreType -eq 'ExportHash')
    {
        $TempFileList = "$env:TEMP\filelist.xml"
        Invoke-StatusUpdate -Message ("[{0} of {1}] :: Hashing the collection of file names exported to [{2}]. Please wait..." -f $i,$s,$TempFileList) `
                        -Step ($stepCounter++) -MaxStep $script:Maxsteps -UpdateUI:$ShowStatusUI `
                        -UpdateTextElement @{'Hash_DeployFiles_Text'='Hashing file list from export...'} `
                        -Outhost -ShowProgress

        #export file list (exclude certain folders in MDT because they update constantly)
        $FileList = Get-ChildItem $WorkingPath -Recurse -Exclude $ExcludeFiles | Where {!($_.PSIsContainer) -and ($_.FullName -notlike '*\backup\*') -and ($_.FullName -notlike '*\Logs\*')}
        #IMPORTANT: don't grab the full directory path as it changes in media, build custom property with the working path removed
        $FileList | Select Length,@{Name = "RootPath"; Expression = {($_.Fullname).replace($workingpath + '\','')}} | Sort Name | Export-Clixml $TempFileList
        #generate hash from XML
        $Hash_DeployFiles = (Get-ChildItem $TempFileList | Get-FileHash).Hash
    }
    Else
    {
        Invoke-StatusUpdate -Message ("[{0} of {1}] :: Hashing the value of files. Please wait..." -f $i,$s) `
                        -Step ($stepCounter++) -MaxStep $script:Maxsteps -UpdateUI:$ShowStatusUI `
                        -UpdateTextElement @{'Hash_DeployFiles_Text'='Hashing file name and sizes...'} `
                        -Outhost -ShowProgress

        #export file list (exclude certain folders in MDT because they update constantly)
        $FileList = Get-ChildItem $WorkingPath -Recurse -Exclude $ExcludeFiles | Where {!($_.PSIsContainer) -and ($_.FullName -notlike '*\backup\*') -and ($_.FullName -notlike '*\Logs\*')}
        #convert the List Object simple string array of <Name>=<Length>. This will make each name unique and hard to replicate. Sort by name to get same order everytime
        $FileTable = ( $FileList | Sort Name | %{($_.Name + '=' + $_.Length )} )
        #convrt the array into a single comma deliminated string
        $FileString = $FileTable -join ','
        #get the hash of the string length
        Write-Verbose ("File string is: [{0}]" -f  $FileString)
        Write-Debug ("File string length is: [{0}]" -f  $FileString.length)
        $Hash_DeployFiles = ($FileString.Length | Get-StringHash).Hash
    }

    #apply variable and value to hashtable
    $DeployHashes.Add('Hash_DeployFiles',$Hash_DeployFiles)

} -OutVariable Measured | Out-Null
#filter the measure to just minutes and second
$Measured = $Measured | select @{n="time";e={$_.Minutes,"Minutes",$_.Seconds,"Seconds" -join " "}}

Invoke-StatusUpdate -Message ('Completed [{0}] files in [{1}]' -f $FileList.count, $Measured.Time) `
                -Step ($stepCounter++) -MaxStep $script:Maxsteps -UpdateUI:$ShowStatusUI `
                -UpdateTextElement @{'Hash_DeployFiles_Text'=('{0} [{1}] files' -f $MsgPastVerb,$FileList.count,$Measured.Time)} `
                -UpdateBorderElement @{'Hash_DeployFiles_Text'='1'} `
                -Outhost -ShowProgress -DisplayColor Green
#Getting just the folder names
#----------------------------------
$i++
Measure-Command {
    If($StoreType -eq 'ExportHash')
    {
        $TempFolderList = "$env:TEMP\Folderlist.xml"
        Invoke-StatusUpdate -Message ("[{0} of {1}] :: Hashing the collection of Folder names exported to [{2}]. Please wait..." -f $i,$s,$TempFolderList)
                        -Step ($stepCounter++) -MaxStep $script:Maxsteps -UpdateUI:$ShowStatusUI `
                        -UpdateTextElement @{'Hash_DeployFolders_Text'='Hashing folders from export...'} `
                        -Outhost -ShowProgress

        #export folder list (exclude certain folders in MDT because they update constantly)
        $FolderList = Get-ChildItem $WorkingPath -Recurse | Where {($_.PSIsContainer) -and ($_.FullName -notlike '*\backup\*') -and ($_.FullName -notlike '*\Logs\*')}
        #export folder list to xml
        #IMPORTANT: don't grab the full directory path as it changes in media, build custom property with the working path removed
        $FolderList | Select @{Name = "RootPath"; Expression = {($_.Fullname).replace($workingpath + '\','')}} | Sort Name | Export-Clixml $TempFolderList
        #generate hash from XML
        $Hash_DeployFolders = (Get-ChildItem $TempFolderList | Get-FileHash).Hash
        #apply variable and value to hashtable
    }
    Else
    {
        Invoke-StatusUpdate -Message ("[{0} of {1}] :: Hashing the value of folder count. Please wait..." -f $i,$s) `
                        -Step ($stepCounter++) -MaxStep $script:Maxsteps -UpdateUI:$ShowStatusUI `
                        -UpdateTextElement @{'Hash_DeployFolders_Text'='Hashing folders count...'} `
                        -Outhost -ShowProgress

        #export file list (exclude certain folders in MDT because they update constantly)
        $FolderList = Get-ChildItem $WorkingPath -Recurse | Where {($_.PSIsContainer) -and ($_.FullName -notlike '*\backup\*') -and ($_.FullName -notlike '*\Logs\*')}
        #convert the List Object simple string array. Sort by name to get same order everytime
        $FolderTable = ($FolderList | Sort Name | %{($_.Fullname).replace($workingpath + '\','')} )
        #convert the array into a single comma deliminated string
        $FolderString = $FolderTable -join ','
        #get the hash of the string length
        Write-Verbose ("Folder string is: [{0}]" -f $FolderString)
        Write-Debug ("Folder string length is: [{0}]" -f $FolderString.length)
        $Hash_DeployFolders = ($FolderString.Length | Get-StringHash).Hash
    }
    #apply variable and value to hashtable
    $DeployHashes.Add('Hash_DeployFolders',$Hash_DeployFolders)

} -OutVariable Measured | Out-Null
#filter the measure to just minutes and second
$Measured = $Measured | select @{n="time";e={$_.Minutes,"Minutes",$_.Seconds,"Seconds" -join " "}}

Invoke-StatusUpdate -Message ('Completed [{0}] folders in [{1}]' -f $FolderList.count,$Measured.Time) `
                -Step ($stepCounter++) -MaxStep $script:Maxsteps -UpdateUI:$ShowStatusUI `
                -UpdateTextElement @{'Hash_DeployFolders_Text'=('{0} [{1}] folders' -f $MsgPastVerb,$FolderList.count,$Measured.Time)} `
                -UpdateBorderElement @{'Hash_DeployFolders_Text'='1'} `
                -Outhost -ShowProgress -DisplayColor Green

#=======================================================
# ACTIONS
#=======================================================
#What action should be performed to process hashes
$i++
switch($CompareType){

    "StoredHash"   {
                        #assume hashes match and if any don't it will return $false
                        $HashMatch = $True
                        #Export and store should have already ran to ppulate the hashing in Customsettings.ini

                        #Take the remaining percentage, divide it into the counted hashes to get the increments
                        $h = ((100 - $p) / $DeployHashes.Count)

                        #Get the hashes from variable when running in tasksequence, otherwise pull from customsettings.ini
                        If((Test-Path $ExportedFileList -ErrorAction SilentlyContinue) -and (Test-Path $ExportedFolderList -ErrorAction SilentlyContinue)){
                            #generate hash from XML
                            $SourceFiles = (Get-ChildItem $ExportedFileList | Get-FileHash).Hash
                            $SourceFolders = (Get-ChildItem $ExportedFolderList | Get-FileHash).Hash
                        }

                        Write-host ("[{0} of {1}] :: Comparing [{2}] hashes..." -f $i,$s,$DeployHashes.count)

                        $DeployHashes.GetEnumerator() | Foreach-Object {
                            #add the incremental percentage
                            $p = $p + $h
                            #max the percentage if close to it
                            If($p -gt 96){$p = 100}


                            If($Script:tsenv){
                                $StoredHash = $tsenv.Value($_.Key)
                            }
                            Else{
                                $StoredHash = $FileContent["Default"][$_.Key]
                            }

                            If($StoredHash -eq $_.Value){
                                Invoke-StatusUpdate -Message ("[{0} = {1}] is valid" -f $_.Key,$_.value) `
                                        -Step ($stepCounter++) -MaxStep $script:Maxsteps -UpdateUI:$ShowStatusUI `
                                        -ShowUIElement ($_.Key + '_Check') -Outhost -ShowProgress -DisplayColor Green
                            }
                            Else
                            {
                                Invoke-StatusUpdate -Message ("[{0} <> {1}] is NOT valid. Stored value is [{2}]" -f $_.Key,$_.value,$StoredHash) `
                                        -Step ($stepCounter++) -MaxStep $script:Maxsteps -UpdateUI:$ShowStatusUI `
                                        -ShowUIElement ($_.Key + '_Alert') -Outhost -ShowProgress -DisplayColor Red

                                $HashMatch = $False
                            }
                            #Show-ProgressStatus -Message $message -Step ($stepCounter++) -MaxStep $script:Maxsteps
                        }

                        If(!$HashMatch){
                            Invoke-StatusUpdate -Message ("Found invalid hash(es). See below status") `
                                        -Step $script:Maxsteps -MaxStep $script:Maxsteps -UpdateUI:$ShowStatusUI `
                                        -HideUIElement 'CloseWindow' `
                                        -ShowUIElement 'Shutdown' -Outhost -ShowProgress -DisplayColor Red
                            Exit 1
                        }
                        Else{
                            #export value if running in Task Sequence
                            If($Script:tsenv){$tsenv.Value("Hash_Valid") = $HashMatch}
                            If(Test-IsISE -or Test-VSCode){Write-Host ("Hash_Valid={0}" -f $HashMatch)}

                            Invoke-StatusUpdate -Message ("All content hashes are valid") `
                                        -Step $script:Maxsteps -MaxStep $script:Maxsteps -UpdateUI:$ShowStatusUI `
                                        -Outhost -ShowProgress -DisplayColor Green
                        }
                    }
}#end action

