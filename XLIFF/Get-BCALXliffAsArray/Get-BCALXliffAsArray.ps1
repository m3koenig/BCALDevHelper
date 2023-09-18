function Get-BCALXliffAsArray {
    [CmdletBinding()]
    Param(
        # Path of the XLIFF File
        [Parameter(Mandatory = $true)]
        [string]$XliffFilePath,
        [string]$LogFilePath
    )

    Write-BCALLog "Load XLIFF file: $XliffFilePath" -logfile $LogFilePath
    [xml]$xliff = Get-Content -Path $XliffFilePath -Encoding UTF8
    $LanguageCode = $xliff.xliff.file.'target-language'
    Write-BCALLog "Language Code of XLIFF file: $LanguageCode" -logfile $LogFilePath

    $transUnits = @()
    foreach ($transUnit in $xliff.xliff.file.body.group."trans-unit") {
        $transUnitObj = New-Object -TypeName PSObject
        $transUnitObj | Add-Member -MemberType NoteProperty -Name "ID" -Value $transUnit.id
        $transUnitObj | Add-Member -MemberType NoteProperty -Name "Source" -Value $transUnit.source
        $transUnitObj | Add-Member -MemberType NoteProperty -Name "Target" -Value $transUnit.target
        $transUnitObj | Add-Member -MemberType NoteProperty -Name "TargetLanguage" -Value $LanguageCode
        $transUnitObj | Add-Member -MemberType NoteProperty -Name "Notes" -Value $transUnit.note            
        $transUnits += $transUnitObj
    }

    return $transUnits
}

Export-ModuleMember -Function Get-BCALXliffAsArray