function Add-Calcfields {
    [CmdletBinding()]
    Param(
        $TableProperty,

        [string]$LogFilePath
    )

    begin {
    }

    process {
        if (($TableProperty.Groups['PropertyName']).ToString().ToLower() -ne 'calcformula') {
            return
        }
        
        Write-BCALLog -Level VERBOSE "-----Add as Calcfield" -logfile $LogFilePath

        [string]$FieldCalcformula = $TableProperty.Groups['PropertyValue'];
        $ALTableFieldProperty = New-Object PSObject
        $ALTableFieldProperty | Add-Member NoteProperty "CalcformulaCode" "$($FieldCalcformula)"

        $TableCalcfields = @()

        # FlowFields Table
        # https://regex101.com/r/wW88aY/1

        $TableFieldCalcformulaRegEx = '^([\s\S]+?\()(".*?")((?:\.)[\S\s]*?)?(?i: WHERE|$|\n)'
        $TableFlowFieldsTableValue = select-string -InputObject $FieldCalcformula -Pattern $TableFieldCalcformulaRegEx -AllMatches | ForEach-Object { $_.Matches }

        if (![string]::IsNullOrEmpty($TableFlowFieldsTableValue)) {
            Write-BCALLog -Level VERBOSE "$($TableFlowFieldsTableValue)" -logfile $LogFilePath
            $TableFlowFieldsTableValue | ForEach-Object {
                $FieldPropertyCalcformulaTable = ($_.Groups[2].Value).Trim();

                $FieldPropertyCalcformulaField = '';
                if (![string]::IsNullOrEmpty($_.Groups[3].Value)) {
                    $FieldPropertyCalcformulaField = ($_.Groups[3].Value).Trim();
                    $FieldPropertyCalcformulaField = $FieldPropertyCalcformulaField.Substring(1, $FieldPropertyCalcformulaField.Length-1);
                }

                $TableFlowfield = New-Object PSObject
                $TableFlowfield | Add-Member NoteProperty "Table" "$($FieldPropertyCalcformulaTable)"
                $TableFlowfield | Add-Member NoteProperty "Field" "$($FieldPropertyCalcformulaField)"
                # $TableFlowfield | Add-Member NoteProperty "Condition" "$($FieldPropertyTableRelationCondition)"
                # $TableFlowfield | Add-Member NoteProperty "TableFilters" "$($FieldPropertyTableRelationFilters)"
                $TableCalcfields += $TableFlowfield

                Write-BCALLog -Level VERBOSE "------IF Calcformula Table Value: $($FieldPropertyCalcformulaTable)" -logfile $LogFilePath
                Write-BCALLog -Level VERBOSE "------IF Calcformula Field Value: $($FieldPropertyCalcformulaField)" -logfile $LogFilePath
            }
        }

        # Write-BCALLog -Level Host $TableCalcfields -logfile $LogFilePath
        $ALTableFieldProperty | Add-Member NoteProperty "Calcformulas" $TableCalcfields
        
        return $ALTableFieldProperty
    }
}