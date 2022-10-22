function Add-Property {
    [CmdletBinding()]
    Param(
        $TableProperty
    )

    begin{
    }

    
    process {
        if ($TableProperty.Groups[1].ToString().ToLower()  -eq 'tablerelation') {
            return
        }
        
        Write-Verbose "-----$($TableProperty.Groups[1]) - $($TableProperty.Groups[2])"

        $ALTableFieldProperty = New-Object PSObject
        $ALTableFieldProperty | Add-Member NoteProperty "$($TableProperty.Groups[1])" "$($TableProperty.Groups[2])"

        return $ALTableFieldProperty
    }
}