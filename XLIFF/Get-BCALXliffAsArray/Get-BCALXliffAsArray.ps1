<#
.SYNOPSIS
    Retrieves the contents of an XLIFF file as an array of objects.
.DESCRIPTION
    This function loads an XLIFF file and returns its contents as an array of objects. Each object represents a "trans-unit" element in the XLIFF file, and contains the following properties:
    - ID: The ID of the "trans-unit" element.
    - Source: The source text of the "trans-unit" element.
    - Target: The target text of the "trans-unit" element.
    - TargetLanguage: The language code of the XLIFF file.
    - Notes: Any notes associated with the "trans-unit" element.
.PARAMETER XliffFilePath
    The path of the XLIFF file to load.
.PARAMETER LogFilePath
    The path of the log file to write to.
.EXAMPLE
    # Loads the XLIFF file "C:\MyXliffFile.xlf" and returns its contents as an array of objects. Writes log messages to the file "C:\MyLog.log". 
    Get-BCALXliffAsArray -XliffFilePath "C:\MyXliffFile.xlf" -LogFilePath "C:\MyLog.log"
    
.EXAMPLE
    # Loads the XLIFF file "C:\MyXliffFile.xlf" and search in the trans-units for the target text for "Assembly Order". Writes log messages to the file "C:\MyLog.log".
    $toTranslate = 'Assembly Order'
    $transUnits = Get-BCALXliffAsArray -XliffFilePath "C:\MyXliffFile.xlf" -LogFilePath "C:\MyLog.log"
    $transUnit = $transUnits | Where-Object { ($_.Source -eq $toTranslate) -and ($null -ne $_.Target) -and ($null -ne $_.TargetLanguage) -and ($_.Target -ne "") } 
    $transUnit
#>

function Get-BCALXliffAsArray {
    [CmdletBinding()]
    Param(
        # Path of the XLIFF File        
        [string]$XliffFilePath,
        [string]$LogFilePath
    )

    # if ([string]::IsNullOrWhiteSpace($XliffFilePath)) {
    #     $XliffGitHubFile = "https://raw.githubusercontent.com/StefanMaron/MSDyn365BC.Code.History/master/BaseApp/Source/German%20language%20(Germany)/Translations/Base%20Application.de-DE.xlf"
    #     $tempXlifGitHubFile = Join-Path $env:TEMP "XLIFTemp.xlf"
    #     Invoke-WebRequest -UseBasicParsing -uri $XliffGitHubFile -OutFile $tempXlifGitHubFile
    #     $XliffFilePath = $tempXlifGitHubFile
    # }

    Write-BCALLog "Load XLIFF file: $($XliffFilePath) ..." -logfile $LogFilePath
    # [System.Xml.XmlDocument]$xliff = Get-Content -Path $XliffFilePath -Encoding UTF8 
    [System.Xml.XmlDocument]$xliff = [System.IO.File]::ReadAllLines($XliffFilePath)
    $LanguageCode = $xliff.xliff.file.'target-language'
    Write-BCALLog "Language Code of XLIFF file: $LanguageCode" -logfile $LogFilePath
    
    $transUnits = @()
    Write-BCALLog "Load only Trans-Units with Source and an Target (could needs some time)..." -logfile $LogFilePath
    $xfliffTransunits = $xliff.xliff.file.body.group."trans-unit" | Where-Object { ([String]::IsNullOrWhiteSpace($_.source) -eq $false) }
    # Write-BCALLog ">>Trans-Units Quantiy: $($xfliffTransunits.count)";
    # $xfliffTransunits  only of the psobject.properties hat an element "target"
    # 6 Minutes for Base App.....
    # 2023.10.23 17:51:53 INFO >>Trans-Units Quantiy: 130184
    # 2023.10.23 17:57:21 INFO >>Trans-Units Quantiy: 127754
    $xfliffTransunits = $xfliffTransunits | Where-Object { $null -ne ($_.psobject.properties | Where-Object { $_.Name -eq "Target" } | Select-Object -ExpandProperty Value) }
    $xfliffTransunitsCount = $xfliffTransunits.count
    Write-BCALLog ">>Trans-Units Quantiy: $($xfliffTransunitsCount)";
    $currXfliffTransunit = 0;
    foreach ($transUnit in $xfliffTransunits ) {
        $currXfliffTransunit += 1
        $currPercent = ($currXfliffTransunit / $xfliffTransunitsCount) * 100;
        $currPercent = [math]::Round($currPercent)
        # Update every 100 entries an progressbar
        if ($currXfliffTransunit % 100 -eq 0) {
            $ProgressTitle = "($($currXfliffTransunit)/$($xfliffTransunitsCount)) - $($transUnit.source)";            
            Write-Progress -Activity $ProgressTitle -Status "$currPercent% Complete:" -PercentComplete $currPercent
        }
        # write-host ">>$($transUnit -is [System.Xml.XmlElement])";
        $targetElement = $transUnit.psobject.properties | Where-Object { $_.Name -eq "Target" } | Select-Object -ExpandProperty Value
        if ($null -eq $targetElement) {
            Write-BCALLog ">Source '$($transUnit.source)' has no translation target node" -logfile $LogFilePath
            continue
        }

        if ($transUnit.target -is [System.Xml.XmlElement]) {
            $targetValue = $transUnit.target.psobject.properties | Where-Object { $_.Name -eq "#text" } | Select-Object -ExpandProperty Value
        }
        else {
            $targetValue = $transUnit.target
        }
        
        $transUnitObj = New-Object -TypeName PSObject
        $transUnitObj | Add-Member -MemberType NoteProperty -Name "ID" -Value $transUnit.id
        $transUnitObj | Add-Member -MemberType NoteProperty -Name "Source" -Value $transUnit.source
        $transUnitObj | Add-Member -MemberType NoteProperty -Name "Target" -Value $targetValue
        $transUnitObj | Add-Member -MemberType NoteProperty -Name "TargetLanguage" -Value $LanguageCode
        $transUnitObj | Add-Member -MemberType NoteProperty -Name "Notes" -Value $transUnit.note
        $transUnits += $transUnitObj
    }
    Write-BCALLog "TransUnits Loaded: $($transUnits.count)" -logfile $LogFilePath
    return $transUnits
}

Export-ModuleMember -Function Get-BCALXliffAsArray