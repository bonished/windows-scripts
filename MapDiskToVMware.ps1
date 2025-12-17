<#
.SYNOPSIS
  Map OS disk numbers to VMware SCSI and LUN locations, with additional info - labels, disk sizes and full path.

.DESCRIPTION
  This script enumerates all disks visible to the operating system,
  retrieves their corresponding VMware SCSI controller and target/LUN values,
  and collects partition names, disk sizes in GB, and direct partition path.
  Outputs a formatted table linking OS disks to VMware storage locations.
  
.INPUTS
  None required; script queries local system disks and WMI information.
  
.OUTPUTS
  PSCustomObject table with columns:
    - Disk Number      : Disk number as seen by the OS
    - VMware SCSI      : SCSI controller and target/LUN (e.g., SCSI0:0)
    - Partition Name   : Labels of partitions on the disk
    - Disk Size GB     : Disk size rounded to GB
    - Location         : OS direct patition path (e.g., C:\, D:\, M:\templog)

.NOTES
  Author:         Bonished
  Version:        1.0
  Creation Date:  2025-12-17
  
.EXAMPLE
  PS C:\windows\system32> .\MapDiskToVMware.ps1

  Output Example:

  Disk Number VMware SCSI Partition Name Disk Size GB Location
  ----------- ------------ -------------- ------------ ----------------
  0           SCSI0:0      OS             80           C:\
  1           SCSI1:1      DATA           200          D:\
  13          SCSI2:5      templog        540          M:\templog\
#>

# Retrieve all physical disks from WMI
$diskDrives = Get-CimInstance Win32_DiskDrive

# Enumerate OS disks with a valid Number
Get-Disk | ? { $_.Number -ne $null } | Sort-Object Number | % {
    $disk       = $_
    $wmiDisk    = $diskDrives | ? Index -eq $disk.Number
    $partitions = Get-Partition -DiskNumber $disk.Number -ErrorAction SilentlyContinue

    # Extract VMware SCSI controller and target/LUN
    $scsiController = $disk.Location      # Controller part from OS
    $scsiTarget     = $wmiDisk.SCSITargetId  # Target/LUN from WMI

    # Create output object
    [pscustomobject]@{
        'Disk Number'    = $disk.Number
        'VMware SCSI'    = "${scsiController}:${scsiTarget}"  # SCSI mapping
        'Partition Name' = ($partitions | % { Get-Volume -Partition $_ -ErrorAction SilentlyContinue } |
                             % FileSystemLabel | ? {$_} | Sort-Object -Unique) -join ', ' # Labels
        'Disk Size GB'   = [math]::Round($disk.Size/1GB,2)  # Size in GB
        'Location'       = ($partitions.AccessPaths | ? {$_ -match '^[A-Z]:\\'} |
                             Sort-Object -Unique) -join ', ' # Direct partition location
    }
} | Format-Table -AutoSize

