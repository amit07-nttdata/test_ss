[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Accept inputs from StackStorm
$dns_domain = $args[0]
$service_name = $args[1]

$hostname = hostname

if ($dns_domain) {
    $Computer = "$hostname.$dns_domain"
} else {
    $Computer = $hostname
}

$CheckHost = $env:COMPUTERNAME
$ServiceName = $service_name
$CheckHostIP = [System.Net.Dns]::GetHostAddresses($hostname) | Where-Object { $_.ScopeId -eq $null } | ForEach-Object { $_.IPAddressToString }

$error.clear()

Write-Output "CHECKDETAILSSTART"
Write-Output ""
Write-Output "Server performing checks (IP) : $CheckHost ($CheckHostIP)"

$result = Get-WmiObject -Query "SELECT * FROM Win32_PingStatus WHERE Address = '$Computer'" -ErrorAction Stop
if ($result.StatusCode -eq 0) {
    $IP = if ($result.IPV4Address.Address) { $result.IPV4Address } else { $result.IPV6Address }

    Write-Output "Server name being checked : $Computer"
    Write-Output "Pingable : true"
    Write-Output "Pinged IP : $IP"
    Write-Output "$Computer is pingable"
    Write-Output ""
    Write-Output "CHECKDETAILSEND"
    Write-Output ""

    Try {
        $SvcName = Get-WmiObject win32_service -Computer $Computer | Where-Object { ($_.Name -eq $ServiceName) -or ($_.DisplayName -eq $ServiceName) }

        if ($?) {
            Write-Output ""
            Write-Output "SERVICE CHECK SCRIPT BEGIN"
            Write-Output ""
            Write-Output "Service being checked : $ServiceName"
            Write-Output ""

            $service_result = $null

            if ($SvcName) {
                $service_result = Get-WmiObject win32_service -Computer $Computer -ErrorVariable badwmi -ErrorAction SilentlyContinue |
                    Where-Object { ($_.Name -eq $ServiceName) -or ($_.DisplayName -eq $ServiceName) } |
                    Select-Object @{name = 'ServerName'; expression = { $_.__Server } }, Name, DisplayName, PathName, StartName,
                        SystemCreationClassName, ServiceType, State, StartMode, ErrorControl, AcceptPause, DesktopInteract,
                        AcceptStop, Started, ExitCode, CheckPoint, ProcessId, ServiceSpecificExitCode, TagId, TotalSessions,
                        DisconnectedSessions, WaitHint, InstallDate, Status, Description

                Write-Output $service_result

                if (($service_result -clike '*State*') -And ($service_result -clike '*Running*')) {
                    Write-Host "Service state : running on server $Computer"
                } else {
                    Write-Host "Service state : stopped on server $Computer"
                }

                if ($badwmi) {
                    $badwmi = $badwmi | Out-String
                    $badwmi = $badwmi.Substring(0, $badwmi.IndexOf("At "))
                    $badwmi = $badwmi.Substring($badwmi.IndexOf(":") + 2, $badwmi.Length - $badwmi.IndexOf(":") - 3)
                    Write-Output "Issue : $badwmi"
                }
            } else {
                Write-Output ""
                if ($ServiceName) {
                    Write-Host "Service state : not-found on server $Computer"
                    Write-Output "########## $ServiceName service is not found on server $Computer ##########"
                } else {
                    Write-Host "Service state : no-service-passed on to script $Computer"
                }
                Write-Output "                                                                                                                                          "
            }

            Write-Output "SERVICE CHECK SCRIPT END"
            Write-Output ""

            # --------- HTML OUTPUT SECTION ----------
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
  <div class='header'>Host Check Details</div>
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
  <div class='header'>Service Check Details</div>
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
  <div class='header'>Service Check Details</div>
  <p>Service <b>$ServiceName</b> not found or not provided.</p>
</div>
"@
            }

            $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            $html_timestamp = @"
<div class='section'>
  <div class='header'>Timestamp</div>
  <p>$timestamp</p>
</div>
"@

            $html_output = $html_header + $html_host_section + $html_service_section + $html_timestamp + $html_footer

            Write-Output "`n==============================="
            Write-Output "HTML_OUTPUT_START"
            Write-Output $html_output
            Write-Output "HTML_OUTPUT_END"
            Write-Output "==============================="

            exit 0
        } else {
            exit 9999
        }
    } Catch {
        exit 9999
    }
} else {
    Write-Output "Server $Computer not pingable from $CheckHost"
    Write-Output ""
    Write-Output "CHECKDETAILSEND"
}
