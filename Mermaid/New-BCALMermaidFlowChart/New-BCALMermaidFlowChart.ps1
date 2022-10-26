# TODO: Docu
function New-BCALMermaidFlowChart {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'SourcePath')]
        [string]$SourceFilePath,
        [Parameter(Mandatory = $true, ParameterSetName = 'BCALDevHelperObjects')]
        [psobject]$ALObjects
    )

    begin {
        . (Join-Path (get-item $PSScriptRoot).parent.FullName "\utils\Convert-TextToMermaidName.ps1")
    }

    process {
        if ($null -eq $ALObjects) {
            Write-Host ">Loading Objects" -ForegroundColor DarkCyan
            $ALObjects = Get-BCALObjects $SourceFilePath
        }

        $ALObjects = $ALObjects | Where-Object { ($_.Type -eq "table") -or ($_.Type -eq "tableextension")}

        $NextLine = "`r`n"

        # $ALObject | ft
        $ALObjectMermaidClass = '';
        $ALObjectTableRelations = '';
        $ALObjectCalcfields = '';

        Write-Verbose "Start Object Diagram Mermaid..."

        [string]$AlClassDiagramm = "graph TD$($NextLine)"
        $ALObjects | ForEach-Object {
            $ALObject = $_;

            #TODO: Bug das Codeunits auch Felder haben
            if ($ALObject.Type -eq "codeunit") {
                # write-host $ALObject
                # write-host "Name '$($ALObjectField.Name)'"
            }

            $ALObjectName = Convert-TextToMermaidName -InputText $ALObject.Name

            Write-Verbose "#########################################################################################"
            Write-Verbose "-ID $($ALObject.ID)"
            Write-Verbose "-ALObjectName = $($ALObjectName)"

            # [string]$ALObjectMermaidClass += "$($NextLine)"
            # [string]$ALObjectMermaidClass += "   class $($ALObject.Type)_$($ALObjectName){$($NextLine)";
            
            $ALObject.Fields | ForEach-Object {
                $ALObjectField = $_;

                $ALObjectFieldName = Convert-TextToMermaidName -InputText $ALObjectField.Name
                    
                Write-Verbose "--ALObjectFieldName = $($ALObjectFieldName)"
                Write-Verbose "--ID: $($ALObjectField.ID)"
                
                if (![string]::IsNullOrEmpty($ALObjectFieldName)) {
                    # $ALObjectMermaidClass += "     +$($ALObjectField.DataType) $($ALObjectFieldName)()$($NextLine)"
                    
                    $ALObjectField.Properties | ForEach-Object {
                        $ALObjectFieldProperty = $_;
                        # Write-Verbose "---$($ALObjectFieldProperty)"


                        $ALObjectFieldPropertyName = $ALObjectFieldProperty.PSObject.Properties.Name;
                        Write-Verbose "----Name: $($ALObjectFieldPropertyName)"
                        $ALObjectFieldPropertyValue = $ALObjectFieldProperty.PSObject.Properties.Value;
                        Write-Verbose "-----Value: $($ALObjectFieldPropertyValue)"
                        
                        # $ALObjectFieldPropteryTableReleations = Get-Member -InputObject $ALObjectFieldProperty -MemberType Property -Name "TableRelations"
                        
                        if($ALObjectFieldPropertyName -eq "TableRelations") {
                            Write-Verbose "-----TableRelations"
                            $ALObjectFieldProperty.TableRelations | ForEach-Object {
                                $ALObjectFieldPropertyTableRelation = $_;
                                
                                $TableRelationTableName = $ALObjectFieldPropertyTableRelation.Table.Trim();
                                $TableRelationTableField = $ALObjectFieldPropertyTableRelation.Field.Trim()
                                Write-Verbose "------Table: $($TableRelationTableName)"
                                Write-Verbose "------Field: $($TableRelationTableField)"

                                if (![string]::IsNullOrEmpty($TableRelationTableName)){
                                    $TableRelationTableName = Convert-TextToMermaidName -InputText $TableRelationTableName

                                    Write-Verbose "------$($ALObjectName) --> $($TableRelationTableName)"
                                    $ALObjectTableRelations += "   table_$($ALObjectName) --> table_$($TableRelationTableName)$($NextLine)"
                                }

                            }
                        }

                        
                        if($ALObjectFieldPropertyName -eq "Calcformulas") {
                            Write-Verbose "-----Calcformulas"
                            $ALObjectFieldProperty.Calcformulas | ForEach-Object {
                                $ALObjectFieldPropertyCalcformula = $_;

                                $CalcformulaTableName = $ALObjectFieldPropertyCalcformula.Table.Trim();
                                $CalcformulaFieldName = $ALObjectFieldPropertyCalcformula.Field.Trim()
                                Write-Verbose "------Table: $($CalcformulaTableName)"
                                Write-Verbose "------Field: $($CalcformulaFieldName)"

                                if (![string]::IsNullOrEmpty($CalcformulaTableName)){
                                    $CalcformulaTableName = Convert-TextToMermaidName -InputText $CalcformulaTableName

                                    Write-Verbose "------$($ALObjectName) -.-> $($CalcformulaFieldName)"
                                    $ALObjectTableRelations += "   table_$($ALObjectName) -.-> table_$($CalcformulaTableName)$($NextLine)"
                                }

                            }
                        }
                        
                    }
                }
                
            }
            $ALObjectMermaidClass += "  }$($NextLine)"
        }

        [string]$AlClassDiagramm += "$($ALObjectTableRelations) $($ALObjectCalcfields)"
        Write-Verbose "Object Diagram Mermaid created!"

        Write-output $AlClassDiagramm  #| Set-Clipboard
    }
}

Export-ModuleMember -Function New-BCALMermaidFlowChart