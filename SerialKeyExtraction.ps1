$key = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SoftwareProtectionPlatform" -Name BackupProductKeyDefault).BackupProductKeyDefault
Write-Host "Windows serial key is" $key "and it has been copied to clipboard." 
Set-Clipboard $key
Read-Host "Press enter to continue..."
