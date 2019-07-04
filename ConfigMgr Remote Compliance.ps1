#################################
## ConfigMgr Remote Compliance ##
#################################


# Set the source directory
$scriptRoot = [System.AppDomain]::CurrentDomain.BaseDirectory.TrimEnd('\')
if ($scriptRoot -eq $PSHOME.TrimEnd('\')) {
    $scriptRoot = $PSScriptRoot
}
$Source = $scriptRoot

# Load in function library
. "$Source\bin\FunctionLibrary.ps1"


# File hash checks
$XAMLFiles = @(
    "About.xaml"
    "App.xaml"
    "Help.xaml"
    "HelpFlowDocument.xaml"
)

$PSFiles = @(
    "About.ps1"
    "ClassLibrary.ps1"
    "EventLibrary.ps1"
    "FunctionLibrary.ps1"
)

$Hashes = @{
    "About.ps1"             = '30D81D06FD7B561AF92A260CD15A63A3CA7E8981AB75A5B3F7C54DCEC4040CFB'
    "ClassLibrary.ps1"      = 'E526558B23F95F341F07D5E8F578F46CC1BC485FD1E68C281801AD3640617060'
    "EventLibrary.ps1"      = '1A9DE4CA9F0A75A3289E47E5C271BB104EE1E2FD627B2B4472A682310A8EB69C'
    "FunctionLibrary.ps1"   = '3F45C4C6204C14183D10F7E8D03508FFBA883E4F7632FB4CF7367A62E0B32F42'
    "About.xaml"            = '4366B0E00578D2F8CE08C15E488D24561D0A7E95C0186D3137636488F11E1930'
    "App.xaml"              = '3694F7887B31AD6E47A801F47B93E8AEAC522CCEDBB89FB09C690F41E93919B5'
    "Help.xaml"             = 'D61F971EA8D454F9961966CEDB1FB108D625A486664AA08A6D5BB09FB4AA8469'
    "HelpFlowDocument.xaml" = '928C28274AC68C311F703082FCBFA6DB20CBD5279224EC2DD415DEC33A87862D'
}

# Check File Hashes
<#
$XAMLFiles | foreach {

    If ((Get-FileHash -Path "$Source\XAML Files\$_").Hash -ne $Hashes.$_)
    {
        New-PopupMessage -Message "One or more installation files failed a hash check. As a security measure, the installation files cannot be altered to prevent running unauthorized code. Please revert the changes or reinstall the application." -Title "ConfigMgr Remote Compliance" -ButtonType Ok -IconType Stop
        Break
    }
}

$PSFiles | foreach {

    If ((Get-FileHash -Path "$Source\bin\$_").Hash -ne $Hashes.$_)
    {
        New-PopupMessage -Message "One or more installation files failed a hash check. As a security measure, the installation files cannot be altered to prevent running unauthorized code. Please revert the changes or reinstall the application." -Title "ConfigMgr Remote Compliance" -ButtonType Ok -IconType Stop
        Break
    }
}
#>

# Do PS version check
If ($PSVersionTable.PSVersion.Major -lt 5) {
    New-PopupMessage -Message "ConfigMgr Remote Compliance cannot start because it requires PowerShell 5 or greater. Please upgrade your PowerShell version." -Title "ConfigMgr Remote Compliance" -ButtonType Ok -IconType Stop
    Break
}



# Region for defining the UI and creating it's related objects
#region UI

# Load assemblies
Add-Type -AssemblyName PresentationFramework
Add-Type -Path "$Source\bin\MaterialDesignColors.dll"
Add-Type -Path "$Source\bin\MaterialDesignThemes.Wpf.dll"

# Read the XAML code
[XML]$Xaml = [System.IO.File]::ReadAllLines("$Source\XAML Files\App.xaml") 


# Create a synchronized hash table and add the WPF window and its named elements to it
$UI = [System.Collections.Hashtable]::Synchronized(@{ })
$UI.Window = [Windows.Markup.XamlReader]::Load((New-Object -TypeName System.Xml.XmlNodeReader -ArgumentList $xaml))
$xaml.SelectNodes("//*[@*[contains(translate(name(.),'n','N'),'Name')]]") | ForEach-Object -Process {
    $UI.$($_.Name) = $UI.Window.FindName($_.Name)
}

# Add an observable collection as a datasource and set datacontext etc
$UI.DataContext = New-Object System.Collections.ObjectModel.ObservableCollection[Object]
$UI.Baselines = New-Object System.Collections.ObjectModel.ObservableCollection[Object]
$UI.User = New-Object System.Collections.ObjectModel.ObservableCollection[Object]
$UI.VersionHistory = New-Object System.Collections.ObjectModel.ObservableCollection[Object]
$UI.Window.DataContext = $UI.DataContext
$UI.Reports = @()
$UI.CurrentVersion = [double]1.2

# Set icon
$UI.Window.Icon = "$Source\bin\audit.ico"

#endregion

# Load additional "libraries" and scripts

. "$Source\bin\ClassLibrary.ps1"
. "$Source\bin\EventLibrary.ps1"
. "$Source\bin\About.ps1"

# Region to display the UI
#region DisplayUI

# If code is running in ISE, use ShowDialog()...
if ($psISE) {
    $null = $UI.window.Dispatcher.InvokeAsync{ $UI.window.ShowDialog() }.Wait()
}
# ...otherwise run as an application
Else {
    # Make PowerShell Disappear
    $windowcode = '[DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);'
    $asyncwindow = Add-Type -MemberDefinition $windowcode -Name Win32ShowWindowAsync -Namespace Win32Functions -PassThru
    $null = $asyncwindow::ShowWindowAsync((Get-Process -PID $pid).MainWindowHandle, 0)

    $app = New-Object -TypeName Windows.Application
    $app.Run($UI.Window)
}

#endregion