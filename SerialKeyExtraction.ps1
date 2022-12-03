$key = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SoftwareProtectionPlatform" -Name BackupProductKeyDefault).BackupProductKeyDefault
Write-Host "Windows serial key is:" -NoNewline $key
Write-Host
Read-Host "Press enter to continue..."
