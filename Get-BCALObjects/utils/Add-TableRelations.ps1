function Add-TableRelations {
    [CmdletBinding()]
    Param(
        $TableProperty
    )

    begin {
        $ALTableFieldProperty = New-Object PSObject
    }

    process {
        if (($TableProperty.Groups[1]).ToString().ToLower() -ne 'tablerelation') {
            return
        }
        
        Write-Verbose "-----$($TableProperty.Groups[1]) - $($TableProperty.Groups[2])"

        [string]$TableRelationValue = $TableProperty.Groups[2];
        $ALTableFieldProperty | Add-Member NoteProperty "TableRelationCode" "$($TableRelationValue)"

        $TableRelations = @()

        # IF Table Releations
        # https://regex101.com/r/1XF7K6/1

        # TODO: Weitere Tests mit https://regex101.com/r/E0q400/1 um auch Felder mit " zu bekommen

        $TableRelationIfRegEx = '(?:^|\)\) )(".*?")((?:\.)[\S\s]*?)?(?i: WHERE|$|\n)'
        $TableRelationIfValue = select-string -InputObject $TableRelationValue -Pattern $TableRelationIfRegEx -AllMatches | ForEach-Object { $_.Matches }

        if (![string]::IsNullOrEmpty($TableRelationIfValue)) {
            $TableRelationIfValue | ForEach-Object {
                $FieldPropertyTableRelationValue = ($_.Groups[1].Value).Trim();

                $FieldPropertyTableRelationField = '';
                if (![string]::IsNullOrEmpty($_.Groups[2].Value)) {
                    $FieldPropertyTableRelationField = ($_.Groups[2].Value).Trim();
                    $FieldPropertyTableRelationField = $FieldPropertyTableRelationField.Substring(1, $FieldPropertyTableRelationField.Length-1);
                }

                $TableRelation = New-Object PSObject
                $TableRelation | Add-Member NoteProperty "Table" "$($FieldPropertyTableRelationValue)"
                $TableRelation | Add-Member NoteProperty "Field" "$($FieldPropertyTableRelationField)"
                # $TableRelation | Add-Member NoteProperty "Condition" "$($FieldPropertyTableRelationCondition)"
                # $TableRelation | Add-Member NoteProperty "TableFilters" "$($FieldPropertyTableRelationFilters)"
                $TableRelations += $TableRelation

                Write-Verbose "------IF Table Relation Table Value: $($FieldPropertyTableRelationValue)"
                Write-Verbose "------IF Table Relation Field Value: $($FieldPropertyTableRelationField)"
            }
        }

        # Write-Host $TableRelations
        $ALTableFieldProperty | Add-Member NoteProperty "TableRelations" $TableRelations
        
        return $ALTableFieldProperty
    }
}