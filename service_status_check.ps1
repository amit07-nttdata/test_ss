Param(   
  [String]$dns_domain ,$service_name
)

$hostname = hostname

if ($dns_domain) {
  $Computer = $hostname + '.' + $dns_domain
} else {
  $Computer = $hostname
} 

$CheckHost = $env:COMPUTERNAME
$ServiceName = $service_name
$CheckHostIP = [System.Net.Dns]::GetHostAddresses($hostname) | ? { $_.scopeid -eq $null } | % { $_.ipaddresstostring }
$error.clear()
write-output "-NORMAL RESPONSE START-"
write-output "CHECKDETAILSSTART"
write-output ""
write-output "Server performing checks (IP) : $CheckHost ($CheckHostIP)"

$result = Get-WmiObject -Query "SELECT * FROM Win32_PingStatus WHERE Address = '$Computer'" -ErrorAction Stop
if ($result.statuscode -eq 0) {
  If ($result.IPV4Address.Address) { $IP = $result.IPV4Address }
  else { $IP = $result.IPV6Address }

  write-output "Server name being checked : $Computer"
  write-output "Pingable : true"
  write-output "Pinged IP : $IP"
  write-output "$Computer is pingable"
  write-output ""
  write-output "CHECKDETAILSEND"
  write-output ""

  Try {
    $SvcName = get-wmiobject win32_service -Computer $Computer | where-object { ($_.Name -eq $ServiceName) -or ($_.DisplayName -eq $ServiceName) }
    if ($?) {
      write-output ""
      write-output "SERVICE CHECK SCRIPT BEGIN"
      write-output ""
      write-output "Service being checked : $ServiceName"
      write-output ""

      $service_result = $null
      if ($SvcName) {
        $service_result = get-wmiobject win32_service -Computer $Computer -ErrorVariable badwmi -ErrorAction SilentlyContinue |
          where-object { ($_.Name -eq $ServiceName) -or ($_.DisplayName -eq $ServiceName) } |
          select @{name='ServerName';expression={$_.__Server}},Name,DisplayName,PathName,StartName,SystemCreationClassName,ServiceType,State,StartMode,ErrorControl,AcceptPause,DesktopInteract,AcceptStop,Started,ExitCode,CheckPoint,ProcessId,ServiceSpecificExitCode,TagId,TotalSessions,DisconnectedSessions,WaitHint,InstallDate,Status,Description

        write-output $service_result

        if (($service_result -clike '*State*') -And ($service_result -clike '*Running*')) {
          Write-Host 'Service state : running on server' $Computer
        } else {
          Write-Host 'Service state : stopped on server' $Computer
        }

        if ($badwmi) {
          $badwmi = $badwmi | Out-String
          $badwmi = $badwmi.substring(0, $badwmi.indexof("At "))
          $badwmi = $badwmi.substring($badwmi.indexof(":") + 2, $badwmi.length - $badwmi.indexof(":") - 3)
          "Issue : $badwmi"
        }
      }
      else {
        write-output ""
        if ($ServiceName) {
          Write-Host 'Service state : not-found on server' $Computer
          write-output "########## $ServiceName service is not found on server $Computer ##########"
        }
        else {
          Write-Host 'Service state : no-service-passed on to script' $Computer
        }
        write-output "                                                                                                                                          "
      }

      write-output "SERVICE CHECK SCRIPT END"
      write-output ""
      write-output "--NORMAL RESPONSE END-"

      # -------------- Minimal HTML Output --------------
      $html_output = @"
<html><head><style>
body { font-family: Arial; font-size: 14px; }
.section { margin-bottom: 20px; }
table { border-collapse: collapse; width: 100%; }
th, td { border: 1px solid #ccc; padding: 8px; }
</style></head><body>
<div class='section'><h3>Server Check Details</h3>
<p>Server performing checks (IP): $CheckHost ($CheckHostIP)<br/>
Server name being checked: $Computer<br/>
Pingable: true<br/>
Pinged IP: $IP<br/></p></div>
"@

      if ($service_result) {
        $html_output += "<div class='section'><h3>Service Check Details</h3><table><tr><th>Field</th><th>Value</th></tr>`n"
        foreach ($prop in $service_result.psobject.Properties) {
          $name = $prop.Name
          $value = $prop.Value -join "`n" -replace "`r?`n", "<br/>"
          $html_output += "<tr><td><b>$name</b></td><td>$value</td></tr>`n"
        }
        $html_output += "</table></div>"
      } else {
        $html_output += "<div class='section'><h3>Service Check Details</h3><p>Service <b>$ServiceName</b> not found or not provided.</p></div>"
      }

      $html_output += "<div class='section'><h3>Timestamp</h3><p>$(Get-Date -Format "yyyy-MM-dd HH:mm:ss")</p></div></body></html>"

      Write-Output "==============================="
      Write-Output "-HTML RESPONSE START-"
      Write-Output $html_output
      Write-Output "-HTML RESPONSE END-"
      Write-Output "==============================="

      # -------------- End HTML Output -------------------

      exit 0
    }
    else {
      exit 9999
    }
  }
  Catch {
    exit 9999
  }
}
write-output "Server $Computer not pingable from $CheckHost"
write-output ""
write-output "CHECKDETAILSEND"
{
}
