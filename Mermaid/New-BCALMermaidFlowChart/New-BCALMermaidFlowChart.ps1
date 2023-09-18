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
            Write-BCALLog ">Loading Objects" -ForegroundColor DarkCyan
            $ALObjects = Get-BCALObjects $SourceFilePath
        }

        $ALObjects = $ALObjects | Where-Object { ($_.Type -eq "table") -or ($_.Type -eq "tableextension")}

        $NextLine = "`r`n"

        # $ALObject | ft
        $ALObjectMermaidClass = '';
        $ALObjectTableRelations = '';
        $ALObjectCalcfields = '';

        Write-BCALLog -Level VERBOSE "Start Object Diagram Mermaid..."

        [string]$AlClassDiagramm = "graph TD$($NextLine)"
        $ALObjects | ForEach-Object {
            $ALObject = $_;

            #TODO: Bug das Codeunits auch Felder haben
            if ($ALObject.Type -eq "codeunit") {
                # Write-BCALLog $ALObject
                # Write-BCALLog "Name '$($ALObjectField.Name)'"
            }

            $ALObjectName = Convert-TextToMermaidName -InputText $ALObject.Name

            Write-BCALLog -Level VERBOSE "#########################################################################################"
            Write-BCALLog -Level VERBOSE "-ID $($ALObject.ID)"
            Write-BCALLog -Level VERBOSE "-ALObjectName = $($ALObjectName)"

            # [string]$ALObjectMermaidClass += "$($NextLine)"
            # [string]$ALObjectMermaidClass += "   class $($ALObject.Type)_$($ALObjectName){$($NextLine)";
            
            $ALObject.Fields | ForEach-Object {
                $ALObjectField = $_;

                $ALObjectFieldName = Convert-TextToMermaidName -InputText $ALObjectField.Name
                    
                Write-BCALLog -Level VERBOSE "--ALObjectFieldName = $($ALObjectFieldName)"
                Write-BCALLog -Level VERBOSE "--ID: $($ALObjectField.ID)"
                
                if (![string]::IsNullOrEmpty($ALObjectFieldName)) {
                    # $ALObjectMermaidClass += "     +$($ALObjectField.DataType) $($ALObjectFieldName)()$($NextLine)"
                    
                    $ALObjectField.Properties | ForEach-Object {
                        $ALObjectFieldProperty = $_;
                        # Write-BCALLog -Level VERBOSE "---$($ALObjectFieldProperty)"


                        $ALObjectFieldPropertyName = $ALObjectFieldProperty.PSObject.Properties.Name;
                        Write-BCALLog -Level VERBOSE "----Name: $($ALObjectFieldPropertyName)"
                        $ALObjectFieldPropertyValue = $ALObjectFieldProperty.PSObject.Properties.Value;
                        Write-BCALLog -Level VERBOSE "-----Value: $($ALObjectFieldPropertyValue)"
                        
                        # $ALObjectFieldPropteryTableReleations = Get-Member -InputObject $ALObjectFieldProperty -MemberType Property -Name "TableRelations"
                        
                        if($ALObjectFieldPropertyName -eq "TableRelations") {
                            Write-BCALLog -Level VERBOSE "-----TableRelations"
                            $ALObjectFieldProperty.TableRelations | ForEach-Object {
                                $ALObjectFieldPropertyTableRelation = $_;
                                
                                $TableRelationTableName = $ALObjectFieldPropertyTableRelation.Table.Trim();
                                $TableRelationTableField = $ALObjectFieldPropertyTableRelation.Field.Trim()
                                Write-BCALLog -Level VERBOSE "------Table: $($TableRelationTableName)"
                                Write-BCALLog -Level VERBOSE "------Field: $($TableRelationTableField)"

                                if (![string]::IsNullOrEmpty($TableRelationTableName)){
                                    $TableRelationTableName = Convert-TextToMermaidName -InputText $TableRelationTableName

                                    Write-BCALLog -Level VERBOSE "------$($ALObjectName) --> $($TableRelationTableName)"
                                    $ALObjectTableRelations += "   table_$($ALObjectName) --> table_$($TableRelationTableName)$($NextLine)"
                                }

                            }
                        }

                        
                        if($ALObjectFieldPropertyName -eq "Calcformulas") {
                            Write-BCALLog -Level VERBOSE "-----Calcformulas"
                            $ALObjectFieldProperty.Calcformulas | ForEach-Object {
                                $ALObjectFieldPropertyCalcformula = $_;

                                $CalcformulaTableName = $ALObjectFieldPropertyCalcformula.Table.Trim();
                                $CalcformulaFieldName = $ALObjectFieldPropertyCalcformula.Field.Trim()
                                Write-BCALLog -Level VERBOSE "------Table: $($CalcformulaTableName)"
                                Write-BCALLog -Level VERBOSE "------Field: $($CalcformulaFieldName)"

                                if (![string]::IsNullOrEmpty($CalcformulaTableName)){
                                    $CalcformulaTableName = Convert-TextToMermaidName -InputText $CalcformulaTableName

                                    Write-BCALLog -Level VERBOSE "------$($ALObjectName) -.-> $($CalcformulaFieldName)"
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
        Write-BCALLog -Level VERBOSE "Object Diagram Mermaid created!"

        Write-BCALLog -Level output $AlClassDiagramm  #| Set-Clipboard
    }
}

Export-ModuleMember -Function New-BCALMermaidFlowChart