$keylocal = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SoftwareProtectionPlatform"
$key = (Get-ItemProperty -Path $keylocal -Name BackupProductKeyDefault).BackupProductKeyDefault
cls
Write-Host "Windows serial key is:" -NoNewline $key
Write-Host
Read-Host "Press enter to continue..."