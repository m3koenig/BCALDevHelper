function Get-BCALXliffAsArray {
    [CmdletBinding()]
    Param(
        # Path of the XLIFF File
        [Parameter(Mandatory = $true)]
        [string]$XliffFilePath,
        [string]$LogFilePath,
        [switch]$copyFromSource
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
        
        # Handle Missing Translations and the overwrite
        $transUnitTarget = ""
        $targetExist = $($transUnit.PSObject.Properties.Name.contains("target"))
        if ($targetExist) {
            # And Target is filled with a string
            $targetExist = $transUnit.target.GetType() -eq "string"
        }

        if ($targetExist) {
            $transUnitTarget = $transUnit.target
        }
        elseif ((!$targetExist) -and ($copyFromSource)) {
            $transUnitTarget = $transUnit.source
        }

        $transUnitObj | Add-Member -MemberType NoteProperty -Name "Target" -Value $transUnitTarget
        $transUnitObj | Add-Member -MemberType NoteProperty -Name "TargetLanguage" -Value $LanguageCode
        $transUnitObj | Add-Member -MemberType NoteProperty -Name "Notes" -Value $transUnit.note            
        $transUnits += $transUnitObj
    }

    return $transUnits
}

Export-ModuleMember -Function Get-BCALXliffAsArray