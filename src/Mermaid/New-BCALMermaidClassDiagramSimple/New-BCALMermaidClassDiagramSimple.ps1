<#
.SYNOPSIS
    Creates an Text for Mermaid Diagram (https://mermaid-js.github.io/mermaid/#/n00b-gettingStarted) as ClassDiagram
.Parameter SourceFilePath
    This is the root path of the AL Files.
.Example
    New-BCALMermaidClassDiagram -SourceFilePath "C:\temp\ALProject\App\src"
#>
function New-BCALMermaidClassDiagramSimple {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'SourcePath')]
        [string]$SourceFilePath,
        [Parameter(Mandatory = $true, ParameterSetName = 'BCALDevHelperObjects')]
        [psobject]$ALObjects,
        [string]$SearchObjectByName,
        # DataType?
        
        [string]$LogFilePath
    )

    begin {
        . (Join-Path (get-item $PSScriptRoot).parent.FullName "\utils\Convert-TextToMermaidName.ps1")
    }

    process {
        if ($null -eq $ALObjects) {
            Write-BCALLog "Loading Objects" -logfile $LogFilePath
            $ALObjects = Get-BCALObjects $SourceFilePath -DetailedMetadata
        }

        # $ALObjects = $ALObjects | Where-Object { ($_.Type -eq "table") -or ($_.Type -eq "tableextension" ) -or ($_.Type -eq "codeunit") }
        
        $NextLine = "`r`n"
        Write-BCALLog -Level VERBOSE "Start Object Diagram Mermaid..." -logfile $LogFilePath
        
        $ALTables = $ALObjects | Where-Object { ($_.Type -eq "table") -or ($_.Type -eq "tableextension" ) }
        
        $MarkdownRelations = @()

        #region Variables
        $ALTablesVariables = @()
        $ALTables | ForEach-Object {
            $existingVars = $_.HasVariables
            # Write-Host "existingVars $($existingVars)"
            if ($existingVars) {
                $ALTablesVariables += $_.Variables | Where-Object { ($_.SubType -ne "") -and ($_.DataType -ne "") } | Select-Object SubType, DataType, "Source Object Type", "Source Object Name"
            }
        }
        $RelationalDatatypes = @("Codeunit", "Record", "Page", "Query", "Interface")
        $ALTablesVariables = $ALTablesVariables | Where-Object { $RelationalDatatypes.Contains($_.DataType) }
        foreach ($TableVariable in $ALTablesVariables) {
            # Map DataType to ObjectTye
            $ToObjectType = $TableVariable.DataType;
            switch ($ToObjectType.ToLower()) {
                "record" { $ToObjectType = "table" }
            }

            $MarkdownRelation = New-Object PSObject
            $MarkdownRelation | Add-Member NoteProperty "From" "$($TableVariable."Source Object Name")"
            $MarkdownRelation | Add-Member NoteProperty "FromObjectType" "$($TableVariable."Source Object Type")"
            $MarkdownRelation | Add-Member NoteProperty "To" "$($TableVariable.SubType)"
            $MarkdownRelation | Add-Member NoteProperty "ToObjectType" $ToObjectType
            $MarkdownRelation | Add-Member NoteProperty "LinkType" "Variable"
            $MarkdownRelations += $MarkdownRelation;
        }
        #endregion

        # ########################
        
        #region TableRelations
        $ALTables | ForEach-Object {
            $AlFields = $_.Fields
            $AlFields | ForEach-Object {
                $ALFieldProperties = $_.Properties
                $ALFieldProperties | ForEach-Object {                    
                    # $HasTableRelations = $_.PSObject.Properties.Name.Contains("TableRelations");
                    $HasTableRelations = $_.PSObject.Properties.Name.ToLower() -eq "tablerelations";
                                        
                    if ($HasTableRelations) {
                        $_.TableRelations | ForEach-Object { 
                            $MarkdownRelation = New-Object PSObject
                            $MarkdownRelation | Add-Member NoteProperty "From" "$($_."Source Object Name")"
                            $MarkdownRelation | Add-Member NoteProperty "FromObjectType" "$($_."Source Object Type")"
                            $MarkdownRelation | Add-Member NoteProperty "To" "$($_.Table)"
                            $MarkdownRelation | Add-Member NoteProperty "ToObjectType" "table"
                            $MarkdownRelation | Add-Member NoteProperty "LinkType" "TableRelation"
                            $MarkdownRelations += $MarkdownRelation;                            
                        }
                    }
                }
            }
        }   
        #endregion
        # ########################

        $MarkdownRelations = $MarkdownRelations | Sort-Object From
        if (![string]::IsNullOrEmpty($SearchObjectByName)) {          
            $MarkdownRelations = $MarkdownRelations | Where-Object { ($_.From -eq $SearchObjectByName) -or ($_.To -eq $SearchObjectByName) }
        }

        $MarkdownRelationLines = "";        
        foreach ($MarkdownRelation in ($MarkdownRelations)) {
            $MarkdownRelationLine = "  "

            $MarkdownRelationLine += "$($MarkdownRelation.FromObjectType)"
            $MarkdownRelationLine += "$((Convert-TextToMermaidName $MarkdownRelation.From))"

            switch ($MarkdownRelation.LinkType) {
                "Variable" { $MarkdownRelationLine += " ..> "; }
                "TableRelation" { $MarkdownRelationLine += " --> "; }
                Default { $MarkdownRelationLine += " --> "; }
            }
            
            $MarkdownRelationLine += "$($MarkdownRelation.ToObjectType)"
            $MarkdownRelationLine += "$((Convert-TextToMermaidName $MarkdownRelation.To))"
            $MarkdownRelationLine += "$($NextLine)"

            $MarkdownRelationLines += $MarkdownRelationLine
        }


        [string]$AlClassDiagramm = "classDiagram$($NextLine)"        
        [string]$AlClassDiagramm += "$($MarkdownRelationLines)"

        # Write-BCALLog -Level VERBOSE "Object Diagram Mermaid created!" -logfile $LogFilePath

        Write-Output $AlClassDiagramm  #| Set-Clipboard
    }
}

Export-ModuleMember -Function New-BCALMermaidClassDiagramSimple