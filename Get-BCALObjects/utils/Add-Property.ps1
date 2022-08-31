function Add-Property {
    [CmdletBinding()]
    Param(
        $TableProperty
    )

    begin{
        $ALTableFieldProperty = New-Object PSObject
    }

    
    process {
        if (($TableProperty.Groups[1]).ToString().ToLower() -eq 'tablerelation') {
            return
        }
        
        Write-Verbose "-----$($Property.Groups[1]) - $($Property.Groups[2])"

        $ALTableFieldProperty | Add-Member NoteProperty "$($TableProperty.Groups[1])" "$($TableProperty.Groups[2])"

        return $ALTableFieldProperty
    }
}