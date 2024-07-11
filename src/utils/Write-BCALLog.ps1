<#
.SYNOPSIS
    It provices flexible logging capabilities. It allows users to log messages with different log levels and provides options for outputting log messages to the console and/or a log file.

.DESCRIPTION
    The "Write-BCALLog" function formats and logs messages with timestamps and various log levels. Users can specify the log message, log level, a log file path, and choose to log to both the console and a file simultaneously.

.PARAMETER Message
    (Mandatory) The log message to be recorded.

.PARAMETER Level
    (Optional) Specifies the log level (default: "INFO"). Options include INFO, WARN, ERROR, FATAL, DEBUG and VERBOSE.

.PARAMETER logfile
    (Optional) Specifies the path to a log file where messages can be appended.

.PARAMETER LogAndWrite
    (Switch) Allows simultaneous logging to the console and a log file if specified.

.EXAMPLE
    Write-BCALLog -Message "This is an informational message."

.EXAMPLE
    Write-BCALLog -Message "An error occurred." -Level "ERROR"

#>
Function Write-BCALLog {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $True)]
        [string]
        $Message,

        [Parameter(Mandatory = $False)]
        [ValidateSet("INFO", "WARN", "ERROR", "FATAL", "DEBUG", "VERBOSE")]
        [String]
        $Level = "INFO",

        [Parameter(Mandatory = $False)]
        [string]
        $logfile,

        [switch]$LogAndWrite
    )

    $Stamp = (Get-Date).toString("yyyy/MM/dd HH:mm:ss")
    $Line = "$Stamp $Level $Message"
    If ($logfile) {
        Add-Content $logfile -Value $Line
    }

    if (([string]::IsNullOrEmpty($logfile)) -or ($LogAndWrite)) {

        switch ($Level) {
            "WARN" { Write-Warning $Line }
            ("ERROR" -or "FATAL") { Write-Error $Line }
            "DEBUG" { Write-Debug $Line }
            "VERBOSE" { Write-Verbose $Line }
            Default {                
                Write-Host $Line
            }
        }
    }
}

Export-ModuleMember -Function Write-BCALLog