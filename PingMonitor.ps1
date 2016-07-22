$IpAddress = '172.16.129.1'
$MaxFailCount = 3
$AlertMinutes = 15
$x = $true
$Status = @{}
$EmailProperties = @{
    'To' = 'fakemail@fakeaddress.internal'
    'From' = 'alerts@fakeaddress.internal'
    'Priority' = 'High'
    'SmtpServer' = 'fakesmtp.fakeaddress.internal'
    'Port' = 25
}

# Load Status array
foreach ($Ip in $IpAddress){
    $Status.Add("$Ip",[PSCustomObject]@{
            'IPAddress' = $Ip
            'PingSucceeded' = $null
            'Alerted' = $null
            'LastAlert' = $null
            'RoundTripTime' = $null
            'FailedCount' = 0})
}

while ($x){
    foreach ($Ip in $IpAddress){
        $Result = Test-NetConnection -RemoteAddress $Ip -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
        if (-not $Result.PingSucceeded){
                    $Status[$Ip].PingSucceeded = $Result.PingSucceeded
                    $Status[$Ip].RoundTripTime = $null
                    $Status[$Ip].FailedCount += 1 
                    Write-Output "$Ip not responding, failed count $($Status[$Ip].FailedCount)."
                    if ( ( ($Status[$Ip].FailedCount -ge $MaxFailCount) -and (-not $Status[$Ip].Alerted) ) `
                        -or ( ((Get-Date).Minute % $AlertMinutes -eq 0) -and ((Get-Date).Minute -ne $Status[$Ip].LastAlert.Minute) ) ){
                       $Props = @{
                        'Subject' = "Device at $Ip is not responding."
                        'Body' = "Device at $Ip is not responding to pings.  It has gone offline."
                    }
                        Send-MailMessage @Props @EmailProperties
                        Write-Output 'Alert sent.'
                        $Status[$Ip].Alerted = $true
                        $Status[$Ip].LastAlert = Get-Date
                } 
            
        }
        elseif ($Result.PingSucceeded -and $Status[$Ip].Alerted){
            Write-Output "$Ip connectivity restored."
            $Props = @{
                    'Subject' = "Device at $Ip is now responding."
                    'Body' = "Device at $Ip is now responding to pings.  It is now online."
            }
            Send-MailMessage @Props @EmailProperties
            Write-Output 'Email sent.'
            Write-Output 'Resetting alert status.'
            $Status[$Ip].Alerted = $null
            $Status[$Ip].LastAlert = $null
            $Status[$Ip].PingSucceeded = $Result.PingSucceeded
            $Status[$Ip].RoundTripTime = $Result.PingReplyDetails.RoundTripTime
            $Status[$Ip].FailedCount = 0
            }        
        else{
            Write-Output "Response received for IP $Ip, $($Result.PingReplyDetails.RoundtripTime) ms"
            $Status[$Ip].Alerted = $null
            $Status[$Ip].LastAlert = $null
            $Status[$Ip].PingSucceeded = $Result.PingSucceeded
            $Status[$Ip].RoundTripTime = $Result.PingReplyDetails.RoundtripTime
            $Status[$Ip].FailedCount = 0
            }
        
    } # end foreach loop
} # end while loop
