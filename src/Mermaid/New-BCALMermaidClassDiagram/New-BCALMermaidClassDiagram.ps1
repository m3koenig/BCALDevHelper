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
        [psobject]$ALObjects,
        
        [string]$LogFilePath
    )

    begin {
        . (Join-Path (get-item $PSScriptRoot).parent.FullName "\utils\Convert-TextToMermaidName.ps1")
    }

    process {
        if ($null -eq $ALObjects) {
            Write-BCALLog "Loading Objects" -logfile $LogFilePath
            $ALObjects = Get-BCALObjects $SourceFilePath
        }

        $ALObjects = $ALObjects | Where-Object { ($_.Type -eq "table") -or ($_.Type -eq "tableextension" ) -or ($_.Type -eq "codeunit") }

        $NextLine = "`r`n"

        # $ALObject | ft
        $ALObjectMermaidClass = '';
        $ALObjectTableRelations = '';
        $ALObjectCalcfields = '';

        Write-BCALLog -Level VERBOSE "Start Object Diagram Mermaid..." -logfile $LogFilePath

        [string]$AlClassDiagramm = "classDiagram$($NextLine)"
        $ALObjects | ForEach-Object {
            $ALObject = $_;
            Write-BCALLog -Level VERBOSE "#########################################################################################" -logfile $LogFilePath
            Write-BCALLog -Level VERBOSE "ALObject: $($ALObject.Type) - $($ALObject.Id) - $($ALObject.Name)" -logfile $LogFilePath
            if ([string]::IsNullOrEmpty($ALObject.Extends)) {
                Write-BCALLog -Level VERBOSE "Extends $($ALObject.Extends)" -logfile $LogFilePath
            }
            Write-BCALLog -Level VERBOSE "------" -logfile $LogFilePath

            #TODO: Bug das Codeunits auch Felder haben
            # Kein Bug, Standard Object Verhalten bei PS wenn man flexible Attribute anhängt
            if ($ALObject.Type -eq "codeunit") {
                # Write-BCALLog $ALObject
                # Write-BCALLog "Name '$($ALObjectField.Name)'"
            }

            $ALObjectName = Convert-TextToMermaidName -InputText $ALObject.Name
            Write-BCALLog -Level VERBOSE "-ID $($ALObject.ID)" -logfile $LogFilePath
            Write-BCALLog -Level VERBOSE "-ALObjectName = $($ALObjectName)" -logfile $LogFilePath

            [string]$ALObjectMermaidClass += "$($NextLine)"
            [string]$ALObjectMermaidClass += "   class $($ALObject.Type)_$($ALObjectName){$($NextLine)";
            # Write-BCALLog -Level VERBOSE "$($ALObjectMermaidClass)"
            
            if (($ALObject.Type -eq "table") -or ($ALObject.Type -eq "tableextension" )) {
                # Fields!
                $fieldsExist = $($ALObject.PSObject.Properties.Name.contains("Fields"))
                        Write-BCALLog -Level VERBOSE "--Fields Exist!" -logfile $LogFilePath
                if ($fieldsExist) {
                    $ALObject.Fields | ForEach-Object {
                        $ALObjectField = $_;
                        Write-BCALLog -Level VERBOSE "--Load Field..." -logfile $LogFilePath

                        $ALObjectFieldName = Convert-TextToMermaidName -InputText $ALObjectField.Name
                    
                        Write-BCALLog -Level VERBOSE "--ALObjectFieldName = $($ALObjectFieldName)" -logfile $LogFilePath
                        Write-BCALLog -Level VERBOSE "--ID: $($ALObjectField.ID)" -logfile $LogFilePath
                
                        if (![string]::IsNullOrEmpty($ALObjectFieldName)) {
                            $ALObjectMermaidClass += "     +$($ALObjectField.DataType) $($ALObjectFieldName)$($NextLine)"
                    
                            $ALObjectField.Properties | ForEach-Object {
                                $ALObjectFieldProperty = $_;
                                # Write-BCALLog -Level VERBOSE "---$($ALObjectFieldProperty)"


                                $ALObjectFieldPropertyName = $ALObjectFieldProperty.PSObject.Properties.Name;
                                Write-BCALLog -Level VERBOSE "----Name: $($ALObjectFieldPropertyName)" -logfile $LogFilePath
                                $ALObjectFieldPropertyValue = $ALObjectFieldProperty.PSObject.Properties.Value;
                                Write-BCALLog -Level VERBOSE "-----Value: $($ALObjectFieldPropertyValue)" -logfile $LogFilePath
                        
                                # $ALObjectFieldPropteryTableReleations = Get-Member -InputObject $ALObjectFieldProperty -MemberType Property -Name "TableRelations"
                        
                                if ($ALObjectFieldPropertyName -eq "TableRelations") {
                                    Write-BCALLog -Level VERBOSE "-----TableRelations" -logfile $LogFilePath
                                    $ALObjectFieldProperty.TableRelations | ForEach-Object {
                                        $ALObjectFieldPropertyTableRelation = $_;
                                
                                        $TableRelationTableName = $ALObjectFieldPropertyTableRelation.Table.Trim();
                                        $TableRelationTableField = $ALObjectFieldPropertyTableRelation.Field.Trim()
                                        Write-BCALLog -Level VERBOSE "------Table: $($TableRelationTableName)" -logfile $LogFilePath
                                        Write-BCALLog -Level VERBOSE "------Field: $($TableRelationTableField)" -logfile $LogFilePath

                                        if (![string]::IsNullOrEmpty($TableRelationTableName)) {
                                            $TableRelationTableName = Convert-TextToMermaidName -InputText $TableRelationTableName

                                            Write-BCALLog -Level VERBOSE "------$($TableRelationTableName) <.. $($ALObject.Type.ToLower())_$($ALObjectName)" -logfile $LogFilePath
                                            $ALObjectTableRelations += "   table_$($TableRelationTableName) <.. $($ALObject.Type.ToLower())_$($ALObjectName)$($NextLine)"
                                        }

                                    }
                                }

                        
                                if ($ALObjectFieldPropertyName -eq "Calcformulas") {
                                    Write-BCALLog -Level VERBOSE "-----Calcformulas" -logfile $LogFilePath
                                    $ALObjectFieldProperty.Calcformulas | ForEach-Object {
                                        $ALObjectFieldPropertyCalcformula = $_;

                                        $CalcformulaTableName = $ALObjectFieldPropertyCalcformula.Table.Trim();
                                        $CalcformulaFieldName = $ALObjectFieldPropertyCalcformula.Field.Trim()
                                        Write-BCALLog -Level VERBOSE "------Table: $($CalcformulaTableName)" -logfile $LogFilePath
                                        Write-BCALLog -Level VERBOSE "------Field: $($CalcformulaFieldName)" -logfile $LogFilePath

                                        if (![string]::IsNullOrEmpty($CalcformulaTableName)) {
                                            $CalcformulaTableName = Convert-TextToMermaidName -InputText $CalcformulaTableName

                                            Write-BCALLog -Level VERBOSE "------$($CalcformulaTableName) .. $($ALObjectName)" -logfile $LogFilePath
                                            $ALObjectCalcfields += "   table_$($CalcformulaTableName) .. $($ALObject.Type.ToLower())_$($ALObjectName)$($NextLine)"
                                        }

                                    }
                                }
                        
                            }
                        }
                
                    }
                }
            }

            if ($ALObject.Type -eq "codeunit") {
                $ALObject.Procedures | ForEach-Object {
                    $ALObjectProcedure = $_;
                    Write-BCALLog -Level VERBOSE "--Load Procedure..." -logfile $LogFilePath

                    $ALObjectProcedureName = Convert-TextToMermaidName -InputText $ALObjectProcedure.Name
                    
                    Write-BCALLog -Level VERBOSE "--ProcedureName = $($ALObjectProcedureName)" -logfile $LogFilePath
                    Write-BCALLog -Level VERBOSE "--parameter: $($ALObjectProcedure.parameter)" -logfile $LogFilePath
                    Write-BCALLog -Level VERBOSE "--return: $($ALObjectProcedure.return)" -logfile $LogFilePath
                
                    if (![string]::IsNullOrEmpty($ALObjectProcedureName)) {
                        $ALObjectMermaidClass += "     +$($ALObjectProcedureName)()$($NextLine)"
                    }
                }
            }
            $ALObjectMermaidClass += "  }$($NextLine)"
        }

        [string]$AlClassDiagramm += "$($ALObjectTableRelations) $($ALObjectCalcfields) $($ALObjectMermaidClass)"

        Write-BCALLog -Level VERBOSE "Object Diagram Mermaid created!" -logfile $LogFilePath

        Write-Output $AlClassDiagramm  #| Set-Clipboard
    }
}

Export-ModuleMember -Function New-BCALMermaidClassDiagram