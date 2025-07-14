cmd: >
  $OS = Get-WmiObject win32_operatingsystem;
  $BootTime = $OS.ConvertToDateTime($OS.LastBootUpTime);
  $CurrentTime = Get-Date;
  $Uptime = $CurrentTime - $BootTime;
  $ComputerName = $env:COMPUTERNAME;
  $LastUser = (Get-WmiObject Win32_ComputerSystem).UserName;
  if (-not $LastUser) {
    try {
      $LastUser = (Get-WmiObject -Class Win32_LoggedOnUser | Select-Object -First 1 -ExpandProperty Antecedent).ToString().Split('"')[1]
    } catch {
      $LastUser = "N/A"
    }
  };
  $UptimeFriendly = "$($Uptime.Days) days $($Uptime.Hours) hours $($Uptime.Minutes) minutes";
  $HTML = "<table border='1' cellpadding='4' cellspacing='0'>
    <tr><th>Server Name</th><td>$ComputerName</td></tr>
    <tr><th>Current Time</th><td>$CurrentTime</td></tr>
    <tr><th>Last Reboot Time</th><td>$BootTime</td></tr>
    <tr><th>Uptime</th><td>$UptimeFriendly</td></tr>
    <tr><th>Last Logged-on User</th><td>$LastUser</td></tr>
  </table>";
  Write-Output $HTML
