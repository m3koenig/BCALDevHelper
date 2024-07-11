function Add-Property {
    [CmdletBinding()]
    Param(
        $TableProperty,

        [string]$LogFilePath
    )

    begin{
    }

    
    process {
        if ($TableProperty.Groups['PropertyName'].ToString().ToLower() -eq 'tablerelation') {
            return
        }
        
        Write-BCALLog -Level VERBOSE "-----Add Property" -logfile $LogFilePath

        $ALTableFieldProperty = New-Object PSObject
        $ALTableFieldProperty | Add-Member NoteProperty "$($TableProperty.Groups['PropertyName'])" "$($TableProperty.Groups['PropertyValue'])"

        return $ALTableFieldProperty
    }
}