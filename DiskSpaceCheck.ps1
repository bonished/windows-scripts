#Simple OS disk space check PowerShell script - before using, edit your target list .txt file path!
#You can simply change script to check any other disk by renaming Where-Object value with desired partition or check all disks by commenting whole line.

Get-CimInstance -Class Win32_LogicalDisk -ComputerName (Get-Content -Path 'C:\Windows\Temp\targets.txt') |
Select-Object @{Name="SystemName";Expression={$_.SystemName}},
			        @{Name="DeviceID";Expression={$_.DeviceID}},
			        @{Name="Free (%)";Expression={"{0,6:P0}" -f(($_.freespace/1gb) / ($_.size/1gb))}},
			        @{Name="Free Space (GB)";Expression={"{0:N2}" -f ($_.freespace/1gb)}},
			        @{Name="Total Size (GB)";Expression={"{0:N2}" -f ($_.size/1gb)}} |
Where-Object DeviceID -EQ "C:" |
Out-GridView
Pause
