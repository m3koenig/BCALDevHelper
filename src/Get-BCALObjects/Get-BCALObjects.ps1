<#
.SYNOPSIS
Parses Business Central AL Object Files into an Powershell Object.
.DESCRIPTION
Parses Business Central AL Object Files into an Powershell Object.
You also had more Access to Tables. Here are Fields and their Properties and Code. Additional there is an Detail Level at the "TableReleation" Property.
.Parameter SourceFilePath
This is the root path of the AL Files.
.Parameter LogFilePath
This is a File Path to an Log File.
.Parameter DetailedMetadata
Adds to the variables, tablerelations and alcfields of an object the the source object by "Source Object Type", "Source Object ID" and "Source Object Name"
.EXAMPLE
Get-BCALObjects "C:\temp\ALProject\App\src"
.EXAMPLE
Get-BCALObjects "C:\temp\ALProject\App\src" | Where-Object Type -eq "table"
.EXAMPLE
Get-BCALObjects "C:\temp\ALProject\App\src" -VERBOSE | Where-Object {($_.Type -eq "table")} | Select-Object Type, ID
.EXAMPLE
Get-BCALObjects "C:\temp\ALProject\App\src" | Where-Object {($_.Type -eq "table")} | Select-Object Type, ID, Path
.EXAMPLE
Get-BCALObjects "C:\temp\ALProject\App\src" -VERBOSE| Where-Object {($_.Type -eq "table")} | Select-Object Type, ID, Path
.EXAMPLE
Get-BCALObjects "C:\temp\ALProject\App\src" | Where-Object {($_.Type -eq "table") -and ($_.ID -eq 50120)} | Select-Object Type, ID, Path
.EXAMPLE
# Example with the Variables with Detailed Metadata
$Tables = Get-BCALObjects "C:\temp\ALProject\App\src" -DetailedMetadata | Where-Object {($_.Type -eq "table")}
# All Variables with a record as SubType
$Tables.Variables | Where-Object { $_.SubType -ne "" } | Select-Object SubType, "Source Object Type", "Source Object ID", "Source Object Name"
.EXAMPLE
# Example with the TableRelations with Detailed Metadata
$Tables = Get-BCALObjects "C:\temp\ALProject\App\src" -DetailedMetadata | Where-Object {($_.Type -eq "table")}
# All TableRelations with a record as SubType
$Tables.Fields.Properties.TableRelations | Select-Object Table,"Source Object Type", "Source Object ID", "Source Object Name"
#>
function Get-BCALObjects {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourceFilePath,

        [string]$LogFilePath,
        [switch]$DetailedMetadata
    )

    begin {
        . (Join-Path $PSScriptRoot "\utils\Add-TableRelations.ps1")
        . (Join-Path $PSScriptRoot "\utils\Add-Property.ps1")
        . (Join-Path $PSScriptRoot "\utils\Add-Calcfields.ps1")

        $ALObjects = @()
    }

    process {
        Write-BCALLog -Level VERBOSE "SourceFilePath $($SourceFilePath)" -logfile $LogFilePath

        $filter = "*.al"

        Write-BCALLog -Level VERBOSE "Filter files with '$($filter)'" -logfile $LogFilePath

        $ALFiles = @(Get-ChildItem $SourceFilePath -Filter $filter -Recurse)
        $ALFileCount = $ALFiles.Count
        Write-BCALLog -Level VERBOSE "Files: $($ALFileCount)" -logfile $LogFilePath

        $ALFiles | ForEach-Object {
            $CurrFile = $_;
            Write-BCALLog -Level VERBOSE "$($CurrFile.Fullname)" -logfile $LogFilePath
            Write-BCALLog -Level VERBOSE "Path is available:$($(Test-Path $CurrFile.Fullname))" -logfile $LogFilePath

            $file = Get-Item $SourceFilePath -Force -ea SilentlyContinue
            $isSymLink = [bool]($file.Attributes -band [IO.FileAttributes]::ReparsePoint)
            Write-BCALLog -Level VERBOSE "Path is Symlink:$($isSymLink)" -logfile $LogFilePath

            if ((Test-Path $_.Fullname) -and (!$isSymLink)) {

                ## TODO: Ginge sicher auch mit regex :)
                [string]$FileContent = Get-Content -Path $CurrFile.FullName -Raw
                if (![string]::IsNullOrEmpty($FileContent)) {
                    Write-BCALLog -Level VERBOSE "Object found: '$($CurrFile.FullName)'" -logfile $LogFilePath

                }

                # Get Object ObjectType, ID, Name 
                # $regex = '^(\w+)\s(\d*)\s"(.*)"'
                $RegExObjectDefinition = Get-BCALRegExObjectDefinition;

                $FileContentObject = select-string -InputObject $FileContent -Pattern $RegExObjectDefinition -AllMatches | ForEach-Object { $_.Matches }
                
                if ([string]::IsNullOrEmpty($FileContentObject)) {
                    Write-BCALLog -Level WARN "File was found but object is not recognized!" -logfile $LogFilePath                    
                    Write-BCALLog -Level WARN "File: $($CurrFile.FullName)" -logfile $LogFilePath
                    # Write-BCALLog -Level WARN "This File Metadata was get: $($FileContentObject)" -logfile $LogFilePath
                }

                $AlObject = $null;
                if (![string]::IsNullOrEmpty($FileContentObject)) {

                    Write-BCALLog -Level VERBOSE "Object ID found: '$($FileContentObject)'" -logfile $LogFilePath
                    Write-BCALLog -Level VERBOSE  "->$($FileContentObject)" -logfile $LogFilePath

                    $ObjectType = $FileContentObject.Groups['Type'].Value;

                    $ALObject = New-Object PSObject
                    $ALObject | Add-Member NoteProperty "Type" "$($ObjectType.ToLower())"
                    $ALObject | Add-Member NoteProperty "ID" "$($FileContentObject.Groups['ID'].Value)"
                    $ALObject | Add-Member NoteProperty "Name" "$($FileContentObject.Groups['Name'].Value)"
                    $ALObject | Add-Member NoteProperty "Namespace" "$($FileContentObject.Groups['Namespace'].Value)"
                    $ALObject | Add-Member NoteProperty "Path" "$($CurrFile.FullName)"
                    $ALObject | Add-Member NoteProperty "Extends" "$($FileContentObject.Groups[5].Value)"
                    # $ALObject | Add-Member NoteProperty "Object" "$($FileContent)"

                    #region Namespaces
                    # $RegExNamespace = 'namespace.?(?<Namespace>[\s\S\n]*?);';
                    # $Namespaces = (select-string -InputObject $FileContent -Pattern $RegExNamespace -AllMatches | ForEach-Object { $_.Matches })
                    # if ($null -ne $Namespaces) {
                    #     $NamespaceName = $Namespaces[0].Groups['Namespace'].Value
                    #     $ALObject | Add-Member NoteProperty "Namespace" "$($NamespaceName)"
                    # }
                    
                    # Write-BCALLog -Level VERBOSE "--Read all used namespaces of the $($ObjectType.ToLower())..." -logfile $LogFilePath
                    # $RegExUsingNamespaces = 'using.?(?<UsingNamespace>[\s\S\n]*?);';
                    # $UsingNamespacesNameMatches = (select-string -InputObject $FileContent -Pattern $RegExUsingNamespaces -AllMatches | ForEach-Object { $_.Matches })
                    # if (![string]::IsNullOrEmpty($UsingNamespacesNameMatches)) {
                    #     $ALObjectUsingNamespaces = @()

                    #     $UsingNamespacesNameMatches | ForEach-Object {
                    #         $UsingNamespace = $_;

                    #         $ALObjectUsingNamespace = New-Object PSObject
                    #         Write-BCALLog -Level VERBOSE "-->$($UsingNamespace.Groups['UsingNamespace'].Value)" -logfile $LogFilePath

                    #         $ALObjectUsingNamespace | Add-Member NoteProperty "Namespace" "$($UsingNamespace.Groups['UsingNamespace'].Value)"
                                
                    #         $ALObjectUsingNamespaces += $ALObjectUsingNamespace
                    #     }
                    #     $ALObject | Add-Member NoteProperty "UsingNamespaces" $ALObjectUsingNamespaces
                    # }
                    #endregion
                    

                    #region Get Variable Blocks
                    # Get All Variable Blocks
                    Write-BCALLog -Level VERBOSE "--Read all variable declarations of the $($ObjectType.ToLower())..." -logfile $LogFilePath

                    $RegexVariableDeclarations = '(?mi)(?<=var[\r|\n])(?<Variables>[\s\S\n]+?)(?<ClosedBy>begin|(?:.*?)procedure |\})'
                    $AllVariableDeclarationMatches = select-string -InputObject $FileContent -Pattern $RegexVariableDeclarations -AllMatches | ForEach-Object { $_.Matches }
                    if ([string]::IsNullOrEmpty($AllVariableDeclarationMatches)) {
                        $ALObject | Add-Member NoteProperty "HasVariables" $false
                    }else {
                        
                        $ALObjectVariables = @()

                        $AllVariableDeclarationMatches | ForEach-Object {
                            $VariableDeclaration = $_;
                            Write-BCALLog -Level VERBOSE "--- Declaration Part: $($VariableDeclaration.Groups['Variables'].Value)" -logfile $LogFilePath

                            # only when after "var" is "begin", they are global variables
                            $IsGlobalDeclaration = $VariableDeclaration.Groups['ClosedBy'].Value -ne 'begin'
                            
                            $RegExVariables = '(?mi)(?!\s*var)^(?:[^\/]*?)(?<VariableName>[\w]*):.(?<DataType>[\S+]*)(?<!;)?(?<SubType>.*)?;';
                            $VariablesMatches = select-string -InputObject $VariableDeclaration.Groups['Variables'].Value -Pattern $RegExVariables -AllMatches | ForEach-Object { $_.Matches }
                            if (![string]::IsNullOrEmpty($VariablesMatches)) {
                                $VariablesMatches | ForEach-Object {
                                    $Variable = $_;
                                    Write-BCALLog -Level VERBOSE "--->Variable $($Variable.Groups['VariableName'])" -logfile $LogFilePath

                                    $ALObjectVariable = New-Object PSObject
                                    $ALObjectVariable | Add-Member NoteProperty "Name" "$($Variable.Groups['VariableName'])"
                                    $ALObjectVariable | Add-Member NoteProperty "DataType" "$($Variable.Groups['DataType'])"
                                    $ALObjectVariable | Add-Member NoteProperty "Global" "$($IsGlobalDeclaration)"

                                    # https://regex101.com/r/ppW7tJ/1
                                    # Replace the " in the SubType
                                    $SubType = $Variable.Groups['SubType'].Value -replace """";
                                    $LowerSubType = $SubType.ToLower();
                                    if (![string]::IsNullOrEmpty($LowerSubType) -or ($LowerSubType -ne ";")) {
                                        if ($ALObjectVariable.DataType -ne 'label') {
                                            # what about temp?
                                            $ALObjectVariable | Add-Member NoteProperty "SubType" "$($SubType)"
                                        }
                                        else {
                                            # Labels are diffrent.....
                                            $RegExLabel = "(?mi)'(?<Value>.*?)'(?<Properties>, .*?);"
                                            $LabelMatches = select-string -InputObject $VariableDeclaration.Groups['Variables'].Value -Pattern $RegExLabel -AllMatches | ForEach-Object { $_.Matches }
                                            $LabelMatch = $LabelMatches[0];

                                            $ALObjectVariable | Add-Member NoteProperty "LabelValue" "$($LabelMatch.Groups['Value'])"
                                            $ALObjectVariable | Add-Member NoteProperty "Properties" "$($LabelMatch.Groups['Properties'])"
                                        }
                                    }
                                    if ($DetailedMetadata) {
                                        $ALObjectVariable | Add-Member NoteProperty "Source Object Type" "$($ALObject.Type)"
                                        $ALObjectVariable | Add-Member NoteProperty "Source Object ID" "$($ALObject.ID)"
                                        $ALObjectVariable | Add-Member NoteProperty "Source Object Name" "$($ALObject.Name)"
                                        $ALObjectVariable | Add-Member NoteProperty "Source Object Namespace" "$($ALObject.Namespace)"
                                    }

                                    $ALObjectVariables += $ALObjectVariable
                                }
                            }
                        }
                        $ALObject | Add-Member NoteProperty "Variables" $ALObjectVariables
                        $ALObject | Add-Member NoteProperty "HasVariables" $true
                    }
                    Write-BCALLog -Level VERBOSE "----------------------" -logfile $LogFilePath
                    #endregion
                    #region Table/Extension

                    if (($ObjectType.ToLower() -eq 'table') -or ($ObjectType.ToLower() -eq 'tableextension')) {
                        Write-BCALLog -Level VERBOSE "--Read fields of the $($ObjectType.ToLower())..." -logfile $LogFilePath

                        # $RegexField = 'field\(([0-9]*);(.*);(.*)\)[\r\n]+(.*{([^}]*)})'
                        $RegexField = "(?<CodeSummary>(?:\s)\/{3}\s\<summary\>(?<SummaryValue>[\s\S\n]*?)\/{3}\s\<\/summary>(?<SummaryDetails>[\s\S\n]*?))?(?<Field>field\((?<FieldId>[0-9]*);(?<FieldName>.*);(?<FieldDataType>.*)\)[\n\s\S]*?{(?<FieldContent>[\s\n\S]*?)})";
                        $TableFields = select-string -InputObject $FileContent -Pattern $RegexField -AllMatches | ForEach-Object { $_.Matches }

                        Write-BCALLog -Level VERBOSE "----------------------" -logfile $LogFilePath
                        if (![string]::IsNullOrEmpty($TableFields)) {
                            $ALObjectFields = @()

                            $TableFields | ForEach-Object {
                                $Field = $_;

                                $ALObjectField = New-Object PSObject
                                Write-BCALLog -Level VERBOSE "---$($Field.Groups[1].Value) - $($Field.Groups[2].Value) - $($Field.Groups[3].Value)" -logfile $LogFilePath
                                $AlObjectFieldName = $Field.Groups['FieldName'].Value.Trim().Replace("""", "");
                                $AlFieldCode = $Field.Groups['FieldContent'].Value;

                                $ALObjectField | Add-Member NoteProperty "ID" "$($Field.Groups['FieldId'].Value.ToInt32($Null))"
                                $ALObjectField | Add-Member NoteProperty "Name" "$($AlObjectFieldName)"
                                $ALObjectField | Add-Member NoteProperty "DataType" "$($Field.Groups['FieldDataType'].Value.Trim())"
                                $ALObjectField | Add-Member NoteProperty "Code" "$($AlFieldCode)"

                                # $RegexFieldProperties = '(\w+)(?:\s?=\s?)(.+);'
                                $RegexFieldProperties = '(?:^|\s|\t)(?<PropertyName>\w+)(?:\s?=\s?)(?<PropertyValue>[\s\S\n]+?);'
                                $TableFieldProperties = select-string -InputObject $AlFieldCode -Pattern $RegexFieldProperties -AllMatches | ForEach-Object { $_.Matches }

                                if (![string]::IsNullOrEmpty($TableFieldProperties)) {
                                    $ALTableFieldProperties = @()

                                    Write-BCALLog -Level VERBOSE "----Field Properties" -logfile $LogFilePath
                                    # $ALTableFieldProperty = New-Object PSObject
                                    $TableFieldProperties | ForEach-Object {
                                        $Property = $_;
                                        Write-BCALLog -Level VERBOSE "------Check: $($Property.Groups['PropertyName']) - $($Property.Groups['PropertyValue'])" -logfile $LogFilePath

                                        $ALTableFieldProperty = Add-Property -TableProperty $Property
                                        $ALTableFieldProperties += $ALTableFieldProperty

                                        Write-BCALLog -Level VERBOSE "------Check TableRelations" -logfile $LogFilePath
                                        $ALTableFieldProperty = Add-TableRelations -TableProperty $Property -DetailedMetadata:$DetailedMetadata -ALObject $AlObject
                                        $ALTableFieldProperties += $ALTableFieldProperty

                                        Write-BCALLog -Level VERBOSE "------Check CalcFields" -logfile $LogFilePath
                                        $ALTableFieldProperty = Add-Calcfields -TableProperty $Property

                                        
                                        Write-BCALLog -Level VERBOSE "------Add Property" -logfile $LogFilePath
                                        $ALTableFieldProperties += $ALTableFieldProperty
                                    }
                                }
                                Write-BCALLog -Level VERBOSE "----Add Properties" -logfile $LogFilePath
                                # $ALObjectField | Add-Member PSObject $ALTableFieldProperties
                                $ALObjectField | Add-Member NoteProperty "Properties" $ALTableFieldProperties

                                $ALObjectFields += $ALObjectField
                            }
                            Write-BCALLog -Level VERBOSE "++++++++++++++++++++++++++" -logfile $LogFilePath


                            $ALObject | Add-Member NoteProperty "Fields" $ALObjectFields
                        }
                    }
                    #endregion

                    #region Codeunit
                    if ($ObjectType.ToLower() -eq 'codeunit') {

                        Write-BCALLog -Level VERBOSE "--Read procedures of the $($ObjectType.ToLower())..." -logfile $LogFilePath

                        $RegExProcedure = '(?mi)(?<prefix>procedure )(?<name>.*)(?<parameter>\(.*\))(?<return>.*$)(?<code>[\s\S\n]+?end;)'
                        $Procedures = select-string -InputObject $FileContent -Pattern $RegExProcedure -AllMatches | ForEach-Object { $_.Matches }

                        
                        $ALObjectProcedures = @()

                        $Procedures | ForEach-Object {
                            $Procedure = $_;
                          
                            Write-BCALLog -Level VERBOSE "---$($Procedure.Groups['name'])" -logfile $LogFilePath
                            $ALObjectProcedure = New-Object PSObject
                            $ALObjectProcedure | Add-Member NoteProperty "Name" "$($Procedure.Groups['name'])"
                            $ALObjectProcedure | Add-Member NoteProperty "parameter" "$($Procedure.Groups['parameter'])"
                            $ALObjectProcedure | Add-Member NoteProperty "return" "$($Procedure.Groups['return'])"
                            $ALObjectProcedure | Add-Member NoteProperty "code" "$($Procedure.Groups['code'])"

                            
                            Write-BCALLog -Level VERBOSE "---Read variables of the procedure $($ALObjectProcedure.Name)..." -logfile $LogFilePath
                            $ProcedureVariableDeclarationMatches = select-string -InputObject $ALObjectProcedure.code -Pattern $RegexVariableDeclarations -AllMatches | ForEach-Object { $_.Matches }
                            if (![string]::IsNullOrEmpty($ProcedureVariableDeclarationMatches)) {

                                $ProcedureVariableDeclarationMatch = $ProcedureVariableDeclarationMatches[0];
        
                                # $ProcedureVariableDeclarations = New-Object PSObject
                                Write-BCALLog -Level VERBOSE "----$($ProcedureVariableDeclarationMatch.Groups['Variables'].Value)" -logfile $LogFilePath
        
                                # $ProcedureVariableDeclarations | Add-Member NoteProperty "Declarations" "$($VariableDeclaration.Groups['Variables'].Value)"
                                $ALObjectProcedure | Add-Member NoteProperty "Declarations" "$($ProcedureVariableDeclarationMatch.Groups['Variables'].Value)"

                                #region This is my current work
                                # TODO: How to add this in the procedure (we have to go deeper!)
                                $RegExVariables = '(?mi)(?!\s*var)^(?:[^\/]*?)(?<VariableName>[\w]*):.(?<DataType>[\S+]*)(?<!;)?(?<SubType>.*)?;';
                                $VariablesMatches = select-string -InputObject $ProcedureVariableDeclarationMatch.Groups['Variables'].Value -Pattern $RegExVariables -AllMatches | ForEach-Object { $_.Matches }
                                if ([string]::IsNullOrEmpty($VariablesMatches)) {
                                    $ALObjectProcedure | Add-Member NoteProperty "HasVariables" $false
                                }else{
                                    $VariablesMatches | ForEach-Object {
                                        $Variable = $_;
                                        Write-BCALLog -Level VERBOSE "---->Variable $($Variable.Groups['VariableName'])" -logfile $LogFilePath

                                        $ALProcessVariable = New-Object PSObject
                                        $ALProcessVariable | Add-Member NoteProperty "Name" "$($Variable.Groups['VariableName'])"
                                        $ALProcessVariable | Add-Member NoteProperty "DataType" "$($Variable.Groups['DataType'])"

                                        # https://regex101.com/r/ppW7tJ/1
                                        $SubType = $Variable.Groups['SubType'].Value.ToLower();
                                        if (![string]::IsNullOrEmpty($SubType) -or ($SubType -ne ";")) {
                                            if ($ALProcessVariable.DataType -ne 'label') {
                                                # what about temp?
                                                $ALProcessVariable | Add-Member NoteProperty "SubType" "$($Variable.Groups['SubType'])"
                                            }
                                            else {
                                                # Labels are diffrent.....
                                                Write-BCALLog -Level VERBOSE "-----> is a label" -logfile $LogFilePath
                                                $RegExLabel = "(?mi)'(?<Value>.*?)'(?<Properties>, .*?);"
                                                $LabelMatches = select-string -InputObject $ProcedureVariableDeclarationMatch.Groups['Variables'].Value -Pattern $RegExLabel -AllMatches | ForEach-Object { $_.Matches }
                                                $LabelMatch = $LabelMatches[0];

                                                $ALProcessVariable | Add-Member NoteProperty "LabelValue" "$($LabelMatch.Groups['Value'])"
                                                $ALProcessVariable | Add-Member NoteProperty "Properties" "$($LabelMatch.Groups['Properties'])"
                                            }
                                        }
                                    }
                                    # $ALObjectProcedure = New-Object PSObject -Property $ALObjectVariable
                                    $ALObjectProcedure | Add-Member NoteProperty "Variables" $ALProcessVariable
                                    $ALObjectProcedure | Add-Member NoteProperty "HasVariables" $true
                                }

                                
                                #endregion
                            }

                            $ALObjectProcedures += $ALObjectProcedure
                        }
                        $ALObject | Add-Member NoteProperty "Procedures" $ALObjectProcedures
                        
                    }
                    #endregion

                    if ($ObjectType.ToLower() -eq 'page') {

                        Write-BCALLog -Level VERBOSE "--Read properties of the $($ObjectType.ToLower())..." -logfile $LogFilePath
                    }
                }
                $ALObjects += $AlObject
            }
        }

    }

    end {
        return $ALObjects | Sort-Object Type, ID
    }    
}
Export-ModuleMember -Function Get-BCALObjects