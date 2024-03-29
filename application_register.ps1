<#
.SYNOPSIS
  Register application in console with gateway IP

.DESCRIPTION
  This script connects to every server provided in server.txt file 
  located in the same location as script and executes 3 commands;
  First navigates to default folder with <application> binaries
  Second starts <application> process just in case it's not running
  Third register server to gateway IP
  In result server is visible in console and ready to install 
  new version of <application> via GUI console.
  No error handling for now.

.INPUTS
  Server.txt file needs to be present in the same location as script.

.OUTPUTS
  Console confirmation.

.NOTES
  Version:        0.1
  Author:         Bonished
  Creation Date:  2024-03-29
  
.EXAMPLE
  PS C:\windows\system32> .\application_register.ps1
#>


$serversFilePath = "$PSScriptRoot\servers.txt"
$servers = Get-Content -Path $serversFilePath

foreach ($server in $servers) {
	Invoke-Command -ComputerName $server -ScriptBlock {
		cd 'C:\Program Files\MyApp'
    if (!(Get-Process "MyApp" -ea 0)) { Start-Process "C:\Program Files\MyApp\MyApp.exe" -NoNewWindow }
		.\MyApp register -s https://13.37.42.69:666
		} -ErrorAction SilentlyContinue
	Write-Host "Done."
}
