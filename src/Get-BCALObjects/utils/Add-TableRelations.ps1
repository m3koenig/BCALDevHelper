function Add-TableRelations {
    [CmdletBinding()]
    Param(
        $TableProperty,
        [PSObject]$ALObject,
        [switch]$DetailedMetadata,
        
        [string]$LogFilePath
    )

    begin {
    }

    process {
        if (($TableProperty.Groups['PropertyName']).ToString().ToLower() -ne 'tablerelation') {
            return
        }
        
        Write-BCALLog -Level VERBOSE "-----Add as TableRelation" -logfile $LogFilePath

        [string]$TableRelationValue = $TableProperty.Groups[2];
        
        $ALTableRelationProperty = New-Object PSObject
        $ALTableRelationProperty | Add-Member NoteProperty "TableRelationCode" "$($TableRelationValue)"

        $TableRelations = @()

        # IF Table Releations
        # https://regex101.com/r/2j8YCw/1

        # TODO: Weitere Tests mit https://regex101.com/r/E0q400/1 um auch Felder mit " zu bekommen

        $TableRelationIfRegEx = '(?:^|\)\) )(?<Table>(?:(?:".*?")|(?:(?!\n)\S*?)))(?<Field>(?:\.)[\S\s]*?)?(?i: WHERE|$|\n)'
        $TableRelationIfValue = select-string -InputObject $TableRelationValue -Pattern $TableRelationIfRegEx -AllMatches | ForEach-Object { $_.Matches }
        
        Write-BCALLog -Level VERBOSE "------IF Table Relation Value: $($TableRelationIfValue)" -logfile $LogFilePath
        if (![string]::IsNullOrEmpty($TableRelationIfValue)) {
            $TableRelationIfValue | ForEach-Object {
                $FieldPropertyTableRelationValue = ($_.Groups['Table'].Value).Trim() -replace """";

                $FieldPropertyTableRelationField = '';
                if (![string]::IsNullOrEmpty($_.Groups['Field'].Value)) {
                    $FieldPropertyTableRelationField = ($_.Groups['Field'].Value).Trim();
                    $FieldPropertyTableRelationField = $FieldPropertyTableRelationField.Substring(1, $FieldPropertyTableRelationField.Length-1);
                }

                $TableRelation = New-Object PSObject
                $TableRelation | Add-Member NoteProperty "Table" "$($FieldPropertyTableRelationValue)"
                $TableRelation | Add-Member NoteProperty "Field" "$($FieldPropertyTableRelationField)"
                # $TableRelation | Add-Member NoteProperty "Condition" "$($FieldPropertyTableRelationCondition)"
                # $TableRelation | Add-Member NoteProperty "TableFilters" "$($FieldPropertyTableRelationFilters)"
                
                if ($DetailedMetadata) {
                    $TableRelation | Add-Member NoteProperty "Source Object Type" "$($ALObject.Type)"
                    $TableRelation | Add-Member NoteProperty "Source Object ID" "$($ALObject.ID)"
                    $TableRelation | Add-Member NoteProperty "Source Object Name" "$($ALObject.Name)"
                    $TableRelation | Add-Member NoteProperty "Source Object Namespace" "$($ALObject.Namespace)"
                }

                $TableRelations += $TableRelation

                Write-BCALLog -Level VERBOSE "------IF Table Relation Table Value: $($FieldPropertyTableRelationValue)" -logfile $LogFilePath
                Write-BCALLog -Level VERBOSE "------IF Table Relation Field Value: $($FieldPropertyTableRelationField)" -logfile $LogFilePath
            }

            Write-BCALLog -Level VERBOSE "------IF Table Relation Count: $($TableRelations.Count)" -logfile $LogFilePath
        }

        # Write-BCALLog -Level Host $TableRelations -logfile $LogFilePath
        $ALTableRelationProperty | Add-Member NoteProperty "TableRelations" $TableRelations
        
        return $ALTableRelationProperty
    }
}