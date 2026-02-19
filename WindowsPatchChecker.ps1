<#
.SYNOPSIS
	Checks specified Windows Servers for presence of defined monthly KB updates and reports installation status.

.DESCRIPTION
	This script reads a list of server hostnames from servers.txt located in the script directory.
	It connects to each server via PowerShell remoting and:
		• Detects Windows Server version (2012/2016/2019/2022)
		• Retrieves full OS build number (4-part version using registry UBR)
		• Checks if the defined KB update is installed
		• Displays colorized console output per server
		• Tracks failed (missing patch) servers
		• Optionally:
			  - Excludes DMZ servers using -NoDMZ switch (filters hostnames containing BBZ or LBZ)
			  - Displays results in Out-GridView
			  - Exports results to CSV
			  - Lists only failed servers after completion
	
	Input file supports:
		• One hostname per line
		• Multiple hostnames separated by comma or whitespace
		• Automatic trimming and duplicate removal

.INPUTS
	servers.txt (located in script directory)
	Hostnames separated by:
		• New line
		• Comma
		• Space
		• Any combination of whitespace

.OUTPUTS
	Console output (colorized)
	Optional Out-GridView table
	Optional CSV report (KB_Check_Report.txt)

.NOTES
	Author:         Lukasz Horbowski
	Version:        1.0 (BASE FINAL)
	Creation Date:  2026-02-19
	
	Features:
		• Full OS build detection (registry-based UBR)
		• Clean input parsing (split, trim, unique)
		• Optional -NoDMZ filtering
		• Accurate progress bar
		• Failed server counter
		• Optional failed-only listing
	
	Requires:
		• PowerShell remoting enabled
		• Administrative privileges
		• Network connectivity to target servers

.EXAMPLE
	Run against all servers in servers.txt:
	    .\KBCheck.ps1
	
	Run excluding DMZ servers (hostnames containing BBZ or LBZ):
	    .\KBCheck.ps1 -NoDMZ

	Output Example:
		Hostname: SERVER01 OS: 2019 (10.0.17763.5576) Installed Hotfix: KB5075904 Installed on: 02/12/2026
		Hostname: SERVER02 OS: 2016 (10.0.14393.6729) Installed Hotfix: Patch missing Installed on: --/--/---- --:--:--
#>


[CmdletBinding()]
param(
    [switch]$NoDMZ
)

Write-Output "===== KB Check for Windows Server 2012, 2016, 2019 and 2022 ====="

$TextFile = Get-Content "$PSScriptRoot\servers.txt" |
    ForEach-Object { $_ -split '[,\s]+' } |
    ForEach-Object { $_.Trim() } |
    Where-Object { $_ } |
    Sort-Object -Unique

if ($NoDMZ) {
    $TextFile = $TextFile | Where-Object { $_ -notmatch 'BBZ|LBZ' }
}

$lineCount = $TextFile.Count

$W2k22KBs=@("KB5075906")
$W2k19KBs=@("KB5075904")
$W2k16KBs=@("KB5075999")
$W2k12KBs=@("KB5070886")

$iteration=0
$failedServersCount=0

Add-Type -AssemblyName System.Windows.Forms

Write-Warning "WARNING: Please ensure that you have manually entered the correct KB numbers in the script before proceeding or set it after this prompt."

$confirmInput=''
while($confirmInput -notin @('y','n','yes','no')){
    $confirmInput=Read-Host "Have you manually entered the KB numbers? (Yes/No)"
    if($confirmInput -notin @('y','n','yes','no')){
        Write-Host "Invalid input. Please enter 'yes' or 'no'."
    }
}

if($confirmInput -in @('n','no')){
    $enterKbNumbers=Read-Host "Do you want to enter the KB numbers now? (Yes/No)"
    if($enterKbNumbers -in @('y','yes')){
        $W2k22KBs=Read-Host "Enter the KB number for Windows Server 2022:"
        $W2k19KBs=Read-Host "Enter the KB number for Windows Server 2019:"
        $W2k16KBs=Read-Host "Enter the KB number for Windows Server 2016:"
        $W2k12KBs=Read-Host "Enter the KB number for Windows Server 2012:"
    }else{
        Write-Host "Script execution cancelled. Please manually enter the KB numbers and run the script again."
        [System.Windows.Forms.MessageBox]::Show(
            "Script execution cancelled. Please manually enter the KB numbers and run the script again or set them while running script.",
            "Script Execution Cancelled",
            "OK",
            "Warning"
        )
        exit
    }
}

Clear-Host
Write-Output "===== KB Check for Windows Server 2012, 2016, 2019 and 2022 ====="
Write-Output "KB numbers set, starting check. There are $lineCount servers to process."

$output = foreach($ServerName in $TextFile){

    $iteration++
    $serversLeft=$lineCount-$iteration

    Write-Progress -Activity "Processing Servers" `
        -Status "Processing Server $ServerName $iteration/$lineCount, $serversLeft more servers left to complete." `
        -PercentComplete (($iteration/$lineCount)*100)

    $sessionOSVersion=New-PSSession -ComputerName $ServerName -ErrorAction SilentlyContinue

    try{
        $result=Invoke-Command -Session $sessionOSVersion -ScriptBlock {

            $cs=Get-CimInstance Win32_ComputerSystem
            $os=Get-WmiObject Win32_OperatingSystem

            $null=$os.Caption -match '20\d{2}'
            $osYear=$Matches[0]

            $reg="HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion"
            $UBR=(Get-ItemProperty -Path $reg).UBR
            $v=$os.Version.Split('.')
            $full="$($v[0]).$($v[1]).$($v[2]).$UBR"
            $osFormatted="$osYear ($full)"

            $hotfixes=$null

            if($os.Name -like "*2022*"){
                $hotfixes=Get-HotFix -Id $using:W2k22KBs -ErrorAction SilentlyContinue
            }
            elseif($os.Name -like "*2019*"){
                $hotfixes=Get-HotFix -Id $using:W2k19KBs -ErrorAction SilentlyContinue
            }
            elseif($os.Name -like "*2016*"){
                $hotfixes=Get-HotFix -Id $using:W2k16KBs -ErrorAction SilentlyContinue
            }
            elseif($os.Name -like "*2012*"){
                $hotfixes=Get-HotFix -Id $using:W2k12KBs -ErrorAction SilentlyContinue
            }

            [PSCustomObject]@{
                Hostname        = $cs.Name
                OS              = $osFormatted
                InstalledHotfix = $hotfixes.HotFixID
                InstalledOn     = $hotfixes.InstalledOn
                Failed          = $null
            }
        }

        if(-not $result.InstalledHotfix){
            $result.InstalledHotfix="Patch missing"
            $result.InstalledOn="--/--/---- --:--:--"
            $result.Failed=$true
            $failedServersCount++
        }else{
            $result.Failed=$false
        }

        $result | Select-Object Hostname,OS,InstalledHotfix,InstalledOn,Failed

        Write-Host "Hostname:" -NoNewline
        Write-Host " $($result.Hostname)" -ForegroundColor Yellow -NoNewline

        Write-Host " OS:" -NoNewline
        Write-Host " $($result.OS)" -ForegroundColor Cyan -NoNewline

        Write-Host " Installed Hotfix:" -NoNewline
        if($result.Failed){
            Write-Host " $($result.InstalledHotfix)" -ForegroundColor Red -NoNewline
        }else{
            Write-Host " $($result.InstalledHotfix)" -ForegroundColor Green -NoNewline
        }

        Write-Host " Installed on:" -NoNewline
        if($result.Failed){
            Write-Host " $($result.InstalledOn)" -ForegroundColor Red
        }else{
            Write-Host " $($result.InstalledOn)" -ForegroundColor Green
        }

    }catch{
        Write-Host "Error occurred while processing server: $ServerName"
    }finally{
        if($sessionOSVersion){
            $sessionOSVersion | Remove-PSSession
        }
    }

    Write-Verbose "Completed processing server $ServerName."
}

Write-Progress -Activity "Processing Servers" -Status "Processing Complete" -Completed

Write-Host "Total servers processed: $iteration"
Write-Host "Failed servers: $failedServersCount"

$generateReport=''
while($generateReport -notin @('y','n','yes','no')){
    $generateReport=Read-Host "Do you want to generate a report in Out-GridView? (Yes/No)"
}

if($generateReport -in @('y','yes')){
    $output | Out-GridView
}

$saveToFile=''
while($saveToFile -notin @('y','n','yes','no')){
    $saveToFile=Read-Host "Do you want to save the output in a text file? (Yes/No)"
}

if($saveToFile -in @('y','yes')){
    $fileName=Join-Path $PSScriptRoot "KB_Check_Report.txt"
    $output | Export-Csv -Path $fileName -NoTypeInformation
    Write-Host "Output saved to: $fileName"
}

$listFailed=''
while($listFailed -notin @('y','n','yes','no')){
    $listFailed=Read-Host "Do you want to list only failed servers? (Yes/No)"
}

if($listFailed -in @('y','yes')){
    $failedOnly = $output | Where-Object { $_.Failed -eq $true }

    if($failedOnly){
        Write-Host "`n===== FAILED SERVERS =====" -ForegroundColor Red
        $failedOnly | Format-Table -AutoSize
    }else{
        Write-Host "No failed servers detected." -ForegroundColor Green
    }
}

Write-Host "Press any key to exit..."
Read-Host > $null
