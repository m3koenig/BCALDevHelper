Function Write-BCALLog {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $True)]
        [string]
        $Message,

        [Parameter(Mandatory = $False)]
        [ValidateSet("INFO", "WARN", "ERROR", "FATAL", "DEBUG")]
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
        Write-Host $Line
    }
}

Export-ModuleMember -Function Write-BCALLog