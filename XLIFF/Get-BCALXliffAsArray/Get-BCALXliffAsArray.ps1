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
        Write-BCALLog -Level VERBOSE "Source: $($transUnit.source)" -logfile $LogFilePath
        
        
        # Handle Missing Translations and the overwrite
        $transUnitTarget = ""
        $targetExist = $($transUnit.PSObject.Properties.Name.contains("target"))
        if ($targetExist) {
            Write-BCALLog -Level VERBOSE "target node exists: $($targetExist)" -logfile $LogFilePath
            $targetNodeDataType = [string]$transUnit.target.GetType();
            Write-BCALLog -Level VERBOSE "Target Node Data Type: $($targetNodeDataType)" -logfile $LogFilePath
            
            $targetExist = $targetNodeDataType.ToLower() -eq "string"
            Write-BCALLog -Level VERBOSE "targetExist as string: $targetExist" -logfile $LogFilePath
            Write-BCALLog -Level VERBOSE "transUnit.target: $($transUnit.target)" -logfile $LogFilePath

            if ($targetExist) {
                $transUnitTarget = $transUnit.target
            }
            # Write-BCALLog -Level VERBOSE "$($transUnit.source) - targetExist $($targetExist) - $($transUnit.target.GetType()) - $($transUnit.target.GetType() -eq "string")"  -logfile $LogFilePath

            $targetExist = $targetNodeDataType.ToLower() -eq "system.xml.xmlelement"
            Write-BCALLog -Level VERBOSE "targetExist as System.Xml.XmlElement: $targetExist" -logfile $LogFilePath     
            Write-BCALLog -Level VERBOSE "transUnit.target.InnerText $($transUnit.target.InnerText)"            
            if ($targetExist) {
                $transUnitTarget = $transUnit.target.InnerText
            }       
        }

        if ((!$targetExist) -and ($copyFromSource)) {
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