#################################
## ConfigMgr Remote Compliance ##
#################################


# Set the source directory
$OS = (Get-CimInstance -ClassName Win32_OperatingSystem -Property OSArchitecture).OSArchitecture
If ($OS -eq "32-bit")
{
    $ProgramFiles = $env:ProgramFiles
}
If ($OS -eq "64-bit")
{
    $ProgramFiles = ${env:ProgramFiles(x86)}
}

$Source = "$ProgramFiles\SMSAgent\ConfigMgr Remote Compliance"


# Load in function library
. "$Source\bin\FunctionLibrary.ps1"

# Do PS version check
If ($PSVersionTable.PSVersion.Major -lt 5)
{
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
$UI = [System.Collections.Hashtable]::Synchronized(@{})
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
$UI.CurrentVersion = [int]1.0

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
if ($psISE)
{
    $null = $UI.window.Dispatcher.InvokeAsync{$UI.window.ShowDialog()}.Wait()
}
# ...otherwise run as an application
Else
{
    # Make PowerShell Disappear
    $windowcode = '[DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);'
    $asyncwindow = Add-Type -MemberDefinition $windowcode -Name Win32ShowWindowAsync -Namespace Win32Functions -PassThru
    $null = $asyncwindow::ShowWindowAsync((Get-Process -PID $pid).MainWindowHandle, 0)
 
    $app = New-Object -TypeName Windows.Application
    $app.Run($UI.Window)
}

#endregion