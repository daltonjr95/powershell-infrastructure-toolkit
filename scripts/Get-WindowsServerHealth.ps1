
#requires -Version 5.1

<#
.SYNOPSIS
    Collects basic health information from Windows servers.

.DESCRIPTION
    Retrieves operating system information, last boot time,
    and free space on local fixed disks. Exports results to CSV.

.NOTES
    Requires appropriate permissions and remote CIM access.
    Remote queries may fail if network or firewall settings
    prevent access to the target servers.
#>

$Servers = @(
    "SERVER01",
    "SERVER02"
)

$Results = foreach ($Server in $Servers) {
    Write-Host "Checking $Server..." -ForegroundColor Cyan

    try {
        $SessionOption = @{
            ComputerName = $Server
            ErrorAction  = "Stop"
        }

        $OS = Get-CimInstance @SessionOption `
            -ClassName Win32_OperatingSystem

        $Disks = Get-CimInstance @SessionOption `
            -ClassName Win32_LogicalDisk `
            -Filter "DriveType=3"

        $DiskSummary = ($Disks | ForEach-Object {
            $FreePercent = if ($_.Size -gt 0) {
                [math]::Round(100 * $_.FreeSpace / $_.Size, 1)
            } else {
                0
            }

            "$($_.DeviceID) free: $FreePercent%"
        }) -join "; "

        [PSCustomObject]@{
            Server       = $Server
            Status       = "Online"
            OS           = $OS.Caption
            LastBoot     = $OS.LastBootUpTime
            Disks        = $DiskSummary
            CheckedAt    = Get-Date
            ErrorMessage = $null
        }
    }
    catch {
        [PSCustomObject]@{
            Server       = $Server
            Status       = "Error"
            OS           = $null
            LastBoot     = $null
            Disks        = $null
            CheckedAt    = Get-Date
            ErrorMessage = $_.Exception.Message
        }
    }
}

$ReportPath = Join-Path $PSScriptRoot "ServerHealthReport.csv"

$Results | Export-Csv -Path $ReportPath `
    -NoTypeInformation -Encoding UTF8

Write-Host "Report saved to: $ReportPath" -ForegroundColor Green
