<#
.SYNOPSIS
    Creates an Text for Mermaid Diagram (https://mermaid-js.github.io/mermaid/#/n00b-gettingStarted) as ClassDiagram
.Parameter SourceFilePath
    This is the root path of the AL Files.
.Example
    New-BCALMermaidClassDiagram -SourceFilePath "C:\temp\ALProject\App\src"
#>
function New-BCALMermaidClassDiagram {
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
            Write-Host "Loading Objects"
            $ALObjects = Get-BCALObjects $SourceFilePath
        }

        $ALObjects = $ALObjects | Where-Object { ($_.Type -eq "table") -or $_.Type -eq "tableextension" }

        $NextLine = "`r`n"

        # $ALObject | ft
        $ALObjectMermaidClass = '';
        $ALObjectTableRelations = '';
        $ALObjectCalcfields = '';

        Write-Verbose "Start Object Diagram Mermaid..."

        [string]$AlClassDiagramm = "classDiagram$($NextLine)"
        $ALObjects | ForEach-Object {
            $ALObject = $_;
            Write-Verbose "#########################################################################################"
            Write-Verbose "ALObject: $($ALObject.Type) - $($ALObject.Id) - $($ALObject.Name)"
            if ([string]::IsNullOrEmpty($ALObject.Extends)) {
                Write-Verbose "Extends $($ALObject.Extends)"
            }
            Write-Verbose "------"

            #TODO: Bug das Codeunits auch Felder haben
            # Kein Bug, Standard Object Verhalten bei PS wenn man flexible Attribute anhängt
            if ($ALObject.Type -eq "codeunit") {
                # write-host $ALObject
                # write-host "Name '$($ALObjectField.Name)'"
            }

            $ALObjectName = Convert-TextToMermaidName -InputText $ALObject.Name
            Write-Verbose "-ID $($ALObject.ID)"
            Write-Verbose "-ALObjectName = $($ALObjectName)"

            [string]$ALObjectMermaidClass += "$($NextLine)"
            [string]$ALObjectMermaidClass += "   class $($ALObject.Type)_$($ALObjectName){$($NextLine)";
            # Write-Verbose "$($ALObjectMermaidClass)"
            
            $ALObject.Fields | ForEach-Object {
                $ALObjectField = $_;
                Write-Verbose "--Load Field..."

                $ALObjectFieldName = Convert-TextToMermaidName -InputText $ALObjectField.Name
                    
                Write-Verbose "--ALObjectFieldName = $($ALObjectFieldName)"
                Write-Verbose "--ID: $($ALObjectField.ID)"
                
                if (![string]::IsNullOrEmpty($ALObjectFieldName)) {
                    $ALObjectMermaidClass += "     +$($ALObjectField.DataType) $($ALObjectFieldName)()$($NextLine)"
                    
                    $ALObjectField.Properties | ForEach-Object {
                        $ALObjectFieldProperty = $_;
                        # Write-Verbose "---$($ALObjectFieldProperty)"


                        $ALObjectFieldPropertyName = $ALObjectFieldProperty.PSObject.Properties.Name;
                        Write-Verbose "----Name: $($ALObjectFieldPropertyName)"
                        $ALObjectFieldPropertyValue = $ALObjectFieldProperty.PSObject.Properties.Value;
                        Write-Verbose "-----Value: $($ALObjectFieldPropertyValue)"
                        
                        # $ALObjectFieldPropteryTableReleations = Get-Member -InputObject $ALObjectFieldProperty -MemberType Property -Name "TableRelations"
                        
                        if ($ALObjectFieldPropertyName -eq "TableRelations") {
                            Write-Verbose "-----TableRelations"
                            $ALObjectFieldProperty.TableRelations | ForEach-Object {
                                $ALObjectFieldPropertyTableRelation = $_;
                                
                                $TableRelationTableName = $ALObjectFieldPropertyTableRelation.Table.Trim();
                                $TableRelationTableField = $ALObjectFieldPropertyTableRelation.Field.Trim()
                                Write-Verbose "------Table: $($TableRelationTableName)"
                                Write-Verbose "------Field: $($TableRelationTableField)"

                                if (![string]::IsNullOrEmpty($TableRelationTableName)) {
                                    $TableRelationTableName = Convert-TextToMermaidName -InputText $TableRelationTableName

                                    Write-Verbose "------$($TableRelationTableName) <|-- $($ALObject.Type.ToLower())_$($ALObjectName)"
                                    $ALObjectTableRelations += "   table_$($TableRelationTableName) <|-- $($ALObject.Type.ToLower())_$($ALObjectName)$($NextLine)"
                                }

                            }
                        }

                        
                        if ($ALObjectFieldPropertyName -eq "Calcformulas") {
                            Write-Verbose "-----Calcformulas"
                            $ALObjectFieldProperty.Calcformulas | ForEach-Object {
                                $ALObjectFieldPropertyCalcformula = $_;

                                $CalcformulaTableName = $ALObjectFieldPropertyCalcformula.Table.Trim();
                                $CalcformulaFieldName = $ALObjectFieldPropertyCalcformula.Field.Trim()
                                Write-Verbose "------Table: $($CalcformulaTableName)"
                                Write-Verbose "------Field: $($CalcformulaFieldName)"

                                if (![string]::IsNullOrEmpty($CalcformulaTableName)) {
                                    $CalcformulaTableName = Convert-TextToMermaidName -InputText $CalcformulaTableName

                                    Write-Verbose "------$($CalcformulaTableName) <.. $($ALObjectName)"
                                    $ALObjectCalcfields += "   table_$($CalcformulaTableName) <.. $($ALObject.Type.ToLower())_$($ALObjectName)$($NextLine)"
                                }

                            }
                        }
                        
                    }
                }
                
            }
            $ALObjectMermaidClass += "  }$($NextLine)"
        }

        [string]$AlClassDiagramm += "$($ALObjectTableRelations) $($ALObjectCalcfields) $($ALObjectMermaidClass)"

        Write-Verbose "Object Diagram Mermaid created!"

        Write-output $AlClassDiagramm  #| Set-Clipboard
    }
}

Export-ModuleMember -Function New-BCALMermaidClassDiagram