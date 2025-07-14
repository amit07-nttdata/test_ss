cmd: >
  $OS = Get-WmiObject win32_operatingsystem;
  $BootTime = $OS.ConvertToDateTime($OS.LastBootUpTime);
  $CurrentTime = Get-Date;
  $Uptime = $CurrentTime - $BootTime;
  $ComputerName = $env:COMPUTERNAME;

  # Get the last interactive user (logon type 2 = local, 10 = RDP)
  $LogonUser = try {
    $events = Get-WinEvent -FilterHashtable @{LogName='Security'; Id=4624} -MaxEvents 50
    foreach ($event in $events) {
      $xml = [xml]$event.ToXml()
      $logonType = $xml.Event.EventData.Data | Where-Object { $_.Name -eq "LogonType" } | Select-Object -ExpandProperty '#text'
      if ($logonType -eq "2" -or $logonType -eq "10") {
        $user = $xml.Event.EventData.Data | Where-Object { $_.Name -eq "TargetUserName" } | Select-Object -ExpandProperty '#text'
        if ($user -and $user -notmatch "^\$$") { return $user }
      }
    }
    "N/A"
  } catch {
    "N/A"
  }

  $UptimeFriendly = "$($Uptime.Days) days $($Uptime.Hours) hours $($Uptime.Minutes) minutes";
  $HTML = "<table border='1' cellpadding='4' cellspacing='0'>
    <tr><th>Server Name</th><td>$ComputerName</td></tr>
    <tr><th>Current Time</th><td>$CurrentTime</td></tr>
    <tr><th>Last Reboot Time</th><td>$BootTime</td></tr>
    <tr><th>Uptime</th><td>$UptimeFriendly</td></tr>
    <tr><th>Last Logged-on User</th><td>$LogonUser</td></tr>
  </table>";
  Write-Output $HTML
