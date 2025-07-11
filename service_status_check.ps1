[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

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
$CheckHostIP = [System.Net.Dns]::GetHostAddresses($hostname) | Where-Object { $_.ScopeId -eq $null } | ForEach-Object { $_.IPAddressToString }

$error.clear()

write-output "CHECKDETAILSSTART"
write-output ""
write-output "Server performing checks (IP) : $CheckHost ($CheckHostIP)"

$result = Get-WmiObject -Query "SELECT * FROM Win32_PingStatus WHERE Address = '$Computer'" -ErrorAction Stop
if ($result.StatusCode -eq 0) {
    if ($result.IPV4Address.Address) { $IP = $result.IPV4Address }
    else { $IP = $result.IPV6Address }

    write-output "Server name being checked : $Computer"
    write-output "Pingable : true"
    write-output "Pinged IP : $IP"
    write-output "$Computer is pingable"
    write-output ""
    write-output "CHECKDETAILSEND"
    write-output ""

    Try {
        $SvcName = Get-WmiObject win32_service -Computer $Computer | Where-Object { ($_.Name -eq $ServiceName) -or ($_.DisplayName -eq $ServiceName) }

        if ($?) {
            write-output ""
            write-output "SERVICE CHECK SCRIPT BEGIN"
            write-output ""
            write-output "Service being checked : $ServiceName"
            write-output ""

            $service_result = $null

            if ($SvcName) {
                $service_result = Get-WmiObject win32_service -Computer $Computer -ErrorVariable badwmi -ErrorAction SilentlyContinue | 
                    Where-Object { ($_.Name -eq $ServiceName) -or ($_.DisplayName -eq $ServiceName) } | 
                    Select-Object @{name='ServerName';expression={$_.__Server}},Name,DisplayName,PathName,StartName,SystemCreationClassName,
                                  ServiceType,State,StartMode,ErrorControl,AcceptPause,DesktopInteract,AcceptStop,Started,
                                  ExitCode,CheckPoint,ProcessId,ServiceSpecificExitCode,TagId,TotalSessions,DisconnectedSessions,
                                  WaitHint,InstallDate,Status,Description

                write-output $service_result

                if (($service_result -clike '*State*') -and ($service_result -clike '*Running*')) {
                    Write-Host 'Service state : running on server' $Computer
                } else {
                    Write-Host 'Service state : stopped on server' $Computer
                }

                if ($badwmi) {
                    $badwmi = $badwmi | Out-String
                    $badwmi = $badwmi.Substring(0, $badwmi.IndexOf("At "))
                    $badwmi = $badwmi.Substring($badwmi.IndexOf(":") + 2, $badwmi.Length - $badwmi.IndexOf(":") - 3)
                    "Issue : $badwmi"
                }

            } else {
                write-output ""
                if ($ServiceName) {
                    Write-Host 'Service state : not-found on server' $Computer
                    write-output "########## $ServiceName service is not found on server $Computer ##########"
                } else {
                    Write-Host 'Service state : no-service-passed on to script' $Computer
                }
                write-output "                                                                                                                                          "
            }

            write-output "SERVICE CHECK SCRIPT END"
            write-output ""

            # ------- START: HTML Output Generation -------
            $html_header = @"
<html>
<head>
    <style>
        body { font-family: Arial, sans-serif; }
        .section { margin-bottom: 20px; }
        .header { font-size: 18px; font-weight: bold; color: #333; margin-bottom: 10px; }
        table { border-collapse: collapse; width: 100%; }
        th, td { text-align: left; padding: 8px; border: 1px solid #ccc; }
        tr:nth-child(even) { background-color: #f9f9f9; }
    </style>
</head>
<body>
"@

            $html_footer = "</body></html>"

            $html_host_section = @"
<div class='section'>
  <div class='header'>🔍 Host Check Details</div>
  <pre>
Server performing checks (IP) : $CheckHost ($CheckHostIP)
Server name being checked     : $Computer
Pingable                      : true
Pinged IP                     : $IP
$Computer is pingable
  </pre>
</div>
"@

            $html_service_section = ""
            if ($null -ne $service_result) {
                $html_service_section += @"
<div class='section'>
  <div class='header'>🛠 Service Check Details</div>
  <table>
    <tr><th>Field</th><th>Value</th></tr>
"@

                foreach ($prop in $service_result.psobject.Properties) {
                    $name = $prop.Name
                    $value = $prop.Value -join "`n"
                    $value = $value -replace "`r`n", "<br/>"
                    $html_service_section += "<tr><td><b>$name</b></td><td>$value</td></tr>`n"
                }

                $html_service_section += "</table></div>"
            } else {
                $html_service_section += @"
<div class='section'>
  <div class='header'>🛠 Service Check Details</div>
  <p>Service <b>$ServiceName</b> not found or not provided.</p>
</div>
"@
            }

            $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            $html_timestamp = @"
<div class='section'>
  <div class='header'>🕒 Timestamp</div>
  <p>$timestamp</p>
</div>
"@

            $html_output = $html_header + $html_host_section + $html_service_section + $html_timestamp + $html_footer

            Write-Output "`n==============================="
            Write-Output "HTML_OUTPUT_START"
            Write-Output $html_output
            Write-Output "HTML_OUTPUT_END"
            Write-Output "==============================="

            # ------- END: HTML Output Generation -------

            exit 0
        } else {
            exit 9999
        }
    } Catch {
        exit 9999
    }
} else {
    write-output "Server $Computer not pingable from $CheckHost"
    write-output ""
    write-output "CHECKDETAILSEND"
}
