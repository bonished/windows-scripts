[CmdletBinding()]
param ()
# Tested only on 2016 and 2019
# Title
Write-Output "===== KB Check for Windows Server 2012, 2016 and 2019 ====="

# Read the server names from a text file
$TextFile = Get-Content -Path "$PSScriptRoot\servers.txt"

# Get the total number of objects in the text file
$totalObjects = $TextFile.Count

# Define the KBs to check for different operating systems
$W2k19KBs = @("KB5026362")
$W2k16KBs = @("KB5026363")
$W2k12KBs = @("KB5018474")

# Check if Verbose mode is enabled
$VerboseMode = $PSBoundParameters['Verbose']

# Initialize iteration counter and failed servers count
$iteration = 0
$failedServersCount = 0

# Add the required assembly for using the MessageBox class
Add-Type -AssemblyName System.Windows.Forms

# Display a warning message
Write-Warning "Please ensure that you have manually entered the correct KB numbers in the script before proceeding or set it after this prompt."

# Prompt the user to confirm if they have entered the KB numbers
$confirmInput = ''
while ($confirmInput -notin @('y', 'n', 'yes', 'no')) {
    $confirmInput = Read-Host "Have you manually entered the KB numbers? (Yes/No)"

    if ($confirmInput -notin @('y', 'n', 'yes', 'no')) {
        Write-Host "Invalid input. Please enter 'yes' or 'no'."
    }
}

if ($confirmInput -in @('n', 'no')) {
    $enterKbNumbers = Read-Host "Do you want to enter the KB numbers now? (Yes/No)"

    if ($enterKbNumbers -in @('y', 'yes')) {
        $W2k19KBs = Read-Host "Enter the KB number for Windows Server 2019:"
        $W2k16KBs = Read-Host "Enter the KB number for Windows Server 2016:"
        $W2k12KBs = Read-Host "Enter the KB number for Windows Server 2012:"
        Write-Output "KB numbers set, starting check."
    } else {
        Write-Host "Script execution cancelled. Please manually enter the KB numbers and run the script again."
        [System.Windows.Forms.MessageBox]::Show("Script execution cancelled. Please manually enter the KB numbers and run the script again or set them while running script.", "Script Execution Cancelled", "OK", "Warning")
        exit
    }
}

# Initialize an array to store the output objects
$output = foreach ($ServerName in $TextFile) {
    $iteration++

    # Create a PowerShell remoting session to the target server
    $sessionOSVersion = New-PSSession -ComputerName $ServerName -ErrorAction SilentlyContinue

    # Invoke a command on the remote session to retrieve information
    $result = Invoke-Command -Session $sessionOSVersion -ScriptBlock {
        # Get the computer system information
        $computerSystem = Get-CimInstance -ClassName Win32_ComputerSystem

        # Get the operating system information
        $operatingSystem = Get-WmiObject -Class Win32_OperatingSystem

        # Initialize variable to store the installed hotfixes
        $hotfixes = "No KBs to check"

        # Check the operating system version and retrieve corresponding hotfixes
        if ($operatingSystem.Name -like "*2019*") {
            $hotfixes = Get-HotFix -Id $using:W2k19KBs -ErrorAction SilentlyContinue
        }
        elseif ($operatingSystem.Name -like "*2016*") {
            $hotfixes = Get-HotFix -Id $using:W2k16KBs -ErrorAction SilentlyContinue
        }
        elseif ($operatingSystem.Name -like "*2012*") {
            $hotfixes = Get-HotFix -Id $using:W2k12KBs -ErrorAction SilentlyContinue
        }

        # Create a custom object to represent the server and hotfix information
        [PSCustomObject]@{
            Hostname = $computerSystem.Name
            InstalledHotfix = $hotfixes.HotFixID
            InstalledOn = $hotfixes.InstalledOn
            Failed = $null
        }
    }

    # Check if the hotfix was not found on the server
    if (-not $result.InstalledHotfix) {
        $result.InstalledHotfix = "Patch missing"
        $result.InstalledOn = "--/--/---- --:--:--"
        $result.Failed = $true
        $failedServersCount++  # Increment the count of failed servers
    } else {
        $result.Failed = $false # Mark the server as succeeded
    }
    # Create an output object with selected properties
    $outputObject = $result | Select-Object Hostname, InstalledHotfix, InstalledOn, Failed

    # Store the output object in an array
    $outputObject

    # Display the information on the console
    Write-Host "Hostname:" -NoNewline
    if ($result.Failed) {
        Write-Host " $($result.Hostname)" -ForegroundColor Red -NoNewline
    } else {
        Write-Host " $($result.Hostname)" -ForegroundColor Green -NoNewline
    }    
    Write-Host " Installed Hotfix:" -NoNewline
    if ($result.Failed) {
        Write-Host " $($result.InstalledHotfix)" -ForegroundColor Red -NoNewline
    } else {
        Write-Host " $($result.InstalledHotfix)" -ForegroundColor Green -NoNewline
    }
    Write-Host " Installed on:" -NoNewline
    if ($result.Failed) {
        Write-Host " $($result.InstalledOn)" -ForegroundColor Red
    } else {
        Write-Host " $($result.InstalledOn)" -ForegroundColor Green
    }

    # Update the progress bar
    $progressText = "Processing $iteration out of $totalObjects servers"
    Write-Progress -Activity "Checking KBs" -Status $progressText -PercentComplete (($iteration/$totalObjects) * 100)

    # Clean up the PowerShell remoting session
    Start-Sleep 0
    $sessionOSVersion | Remove-PSSession

    # Display verbose message if Verbose mode is enabled
    if ($VerboseMode) {
        Write-Verbose "Completed processing server $ServerName."
    }
}

# Count the number of iterations and display the total number of servers
Write-Host "Total servers listed: $iteration"
if ($VerboseMode) {
    Write-Verbose "Completed counting servers processed."
}
Write-Host "Failed servers: $failedServersCount"
if ($VerboseMode) {
    Write-Verbose "Completed counting failed servers."
}

# Prompt the user if they want to generate a report in Out-GridView
$generateReport = ''
while ($generateReport -notin @('y', 'n', 'yes', 'no')) {
    $generateReport = Read-Host "Do you want to generate a report in Out-GridView? (Yes/No)"

    if ($generateReport -notin @('y', 'n', 'yes', 'no')) {
        Write-Host "Invalid input. Please enter 'y' or 'n'."
    }
}

if ($generateReport -in @('y', 'yes')) {
    # Open the output in Out-GridView for easy viewing
    $output | Out-GridView
}

# Prompt the user if they want to save the output in a text file
$saveToFile = ''
while ($saveToFile -notin @('y', 'n', 'yes', 'no')) {
    $saveToFile = Read-Host "Do you want to save the output in a text file? (Yes/No)"

    if ($saveToFile -notin @('y', 'n', 'yes', 'no')) {
        Write-Host "Invalid input. Please enter 'y' or 'n'."
    }
}

if ($saveToFile -in @('y', 'yes')) {
    $fileName = Join-Path -Path $PSScriptRoot -ChildPath "KB_Check_Report.txt"
    $output | Export-Csv -Path $fileName -NoTypeInformation
    Write-Host "Output saved to: $fileName"
}

# Prompt the user to press a key before exiting
Write-Host "Press any key to exit..."
Read-Host > $null
