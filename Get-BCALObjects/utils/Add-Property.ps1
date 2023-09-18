function Add-Property {
    [CmdletBinding()]
    Param(
        $TableProperty,

        [string]$LogFilePath
    )

    begin{
    }

    
    process {
        if ($TableProperty.Groups[1].ToString().ToLower()  -eq 'tablerelation') {
            return
        }
        
        Write-BCALLog -Level VERBOSE "-----$($TableProperty.Groups[1]) - $($TableProperty.Groups[2])" -logfile $LogFilePath

        $ALTableFieldProperty = New-Object PSObject
        $ALTableFieldProperty | Add-Member NoteProperty "$($TableProperty.Groups[1])" "$($TableProperty.Groups[2])"

        return $ALTableFieldProperty
    }
}