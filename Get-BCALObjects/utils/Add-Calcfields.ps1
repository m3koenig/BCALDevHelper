function Add-Calcfields {
    [CmdletBinding()]
    Param(
        $TableProperty
    )

    begin {
        $ALTableFieldProperty = New-Object PSObject
    }

    process {
        if (($TableProperty.Groups[1]).ToString().ToLower() -ne 'calcformula') {
            return
        }
        
        Write-Verbose "-----$($TableProperty.Groups[1]) - $($TableProperty.Groups[2])"

        [string]$FieldCalcformula = $TableProperty.Groups[2];
        $ALTableFieldProperty | Add-Member NoteProperty "CalcformulaCode" "$($FieldCalcformula)"

        $TableCalcfields = @()

        # FlowFields Table
        # https://regex101.com/r/wW88aY/1

        $TableFieldCalcformulaRegEx = '^([\s\S]+?\()(".*?")((?:\.)[\S\s]*?)?(?i: WHERE|$|\n)'
        $TableFlowFieldsTableValue = select-string -InputObject $FieldCalcformula -Pattern $TableFieldCalcformulaRegEx -AllMatches | ForEach-Object { $_.Matches }

        if (![string]::IsNullOrEmpty($TableFlowFieldsTableValue)) {
            Write-Verbose "$($TableFlowFieldsTableValue)"
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

                Write-Verbose "------IF Calcformula Table Value: $($FieldPropertyCalcformulaTable)"
                Write-Verbose "------IF Calcformula Field Value: $($FieldPropertyCalcformulaField)"
            }
        }

        # Write-Host $TableCalcfields
        $ALTableFieldProperty | Add-Member NoteProperty "Calcformulas" $TableCalcfields
        
        return $ALTableFieldProperty
    }
}