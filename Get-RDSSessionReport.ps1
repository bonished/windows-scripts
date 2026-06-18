
function Get-RDSSessionInfo {
    param(
        [string]$Server
    )
    if (-not $Server) {
        $Server = Read-Host "Enter server name"
    }
    $q = quser /server:$Server 2>$null
    $adCache = @{}
    $sessions = foreach ($l in $q | Select-Object -Skip 1) {
        $l = $l.Trim().TrimStart(">")
        if ($l -match '^(?<U>\S+)\s+(?<S>\S+)\s+(?<I>\d+)\s+(?<T>\S+)\s+(?<Idle>\S+)\s+(?<Logon>.+)$') {
            $user,$sessionName,$id,$state,$idle,$logon = $Matches.U,$Matches.S,$Matches.I,$Matches.T,$Matches.Idle,$Matches.Logon.Trim()
        }
        elseif ($l -match '^(?<U>\S+)\s+(?<I>\d+)\s+(?<T>\S+)\s+(?<Idle>\S+)\s+(?<Logon>.+)$') {
            $user,$sessionName,$id,$state,$idle,$logon = $Matches.U,"",$Matches.I,$Matches.T,$Matches.Idle,$Matches.Logon.Trim()
        }
        else { continue }
        [PSCustomObject]@{
            Username    = ($user -replace '.*\\')
            SessionId   = $id
            State       = $state
            SessionName = $sessionName
            IdleTime    = $idle
            LogonTime   = $logon
        }
    }
    $result = foreach ($s in $sessions) {
        if (-not $adCache.ContainsKey($s.Username)) {
            $adCache[$s.Username] = try { Get-ADUser $s.Username -Properties DisplayName } catch { $null }
        }
        [PSCustomObject]@{
            Username    = $s.Username
            DisplayName = if ($adCache[$s.Username]) { $adCache[$s.Username].DisplayName } else { "NOT FOUND" }
            State       = $s.State
            SessionId   = $s.SessionId
            SessionName = $s.SessionName
            IdleTime    = $s.IdleTime
            LogonTime   = $s.LogonTime
        }
    }
    $result | Sort-Object {[int]$_.SessionId} | Format-Table -AutoSize
    "Unique users: $($result.Username | Sort-Object -Unique | Measure-Object | % Count) | Total sessions: $($result.Count)"
    "Connections by session status:"
    $result | Group-Object State | Select-Object Name, Count | Sort-Object Name | Format-Table -AutoSize
}
if ($MyInvocation.InvocationName -ne '.') { Get-RDSSessionInfo }
