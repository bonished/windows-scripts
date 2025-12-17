<#
.SYNOPSIS
  Schedule a Windows machine reboot remotely from an RDP/jump server.

.DESCRIPTION
  This script connects to a specified remote server and creates a one-time scheduled task 
  to restart the machine at a specified date and time. 
  The scheduled task runs under the SYSTEM account with highest privileges, ensuring the reboot occurs 
  regardless of user session. A comment can be added to the shutdown command (without spaces).

.PARAMETER ServerName
  The hostname or IP of the remote machine where the scheduled reboot will be created.

.INPUTS
  None. ServerName is passed as a parameter.

.OUTPUTS
  Registers a scheduled task on the remote server named "Example Task" that triggers a system reboot.

.NOTES
  Version:        0.2
  Author:         Bonished
  Creation Date:  2025-12-17

.EXAMPLE
  PS C:\windows\system32> .\remote_reboot.ps1 -ServerName "MyServer01"
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$ServerName
)

# Desired reboot date and time (12h or 24h format works)
$RebootDate = Get-Date "2025-11-01 09:00PM"

# Script block to execute on the remote server
$scriptBlock = {

    # Scheduled task action to reboot immediately with comment (no spaces allowed)
    $A = New-ScheduledTaskAction -Execute "shutdown.exe" -Argument "/r /f /t 0 /c '<place_comment_in_apostrophes_and_without_spaces_please>'"

    # Trigger the task once at the specified date
    $T = New-ScheduledTaskTrigger -Once -At $using:RebootDate

    # Run task as SYSTEM with highest privileges
    $P = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

    # Assemble the scheduled task
    $D = New-ScheduledTask -Action $A -Principal $P -Trigger $T

    # Register the scheduled task with a name
    Register-ScheduledTask "Example Task" -InputObject $D
}

# Execute the script block on the remote server
Invoke-Command -ComputerName $ServerName -ScriptBlock $scriptBlock
