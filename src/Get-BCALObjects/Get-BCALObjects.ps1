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
#>
function Get-BCALObjects {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourceFilePath,

        [string]$LogFilePath
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

        $ALFiles = Get-ChildItem $SourceFilePath -Filter $filter -Recurse 
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
                $regex = '(?<Type>\w+)\s(?<ID>\d*)\s"(?<Name>.*?)"(?:\s(extends)\s"(.*)")?'

                $FileContentObject = select-string -InputObject $FileContent -Pattern $regex -AllMatches | ForEach-Object { $_.Matches }
                
                if ([string]::IsNullOrEmpty($FileContentObject)) {
                    Write-BCALLog -Level WARN "File Found but Object not recognized!" -logfile $LogFilePath
                    Write-BCALLog -Level WARN "File: $($CurrFile.FullName)" -logfile $LogFilePath
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
                    $ALObject | Add-Member NoteProperty "Path" "$($CurrFile.FullName)"
                    $ALObject | Add-Member NoteProperty "Extends" "$($FileContentObject.Groups[5].Value)"
                    # $ALObject | Add-Member NoteProperty "Object" "$($FileContent)"

                    $RegExNamespace = 'namespace.?(?<Namespace>[\s\S\n]*?);';
                    $Namespaces = (select-string -InputObject $FileContent -Pattern $RegExNamespace -AllMatches | ForEach-Object { $_.Matches })
                    if ($null -ne $Namespaces) {
                        $NamespaceName = $Namespaces[0].Groups['Namespace'].Value
                        $ALObject | Add-Member NoteProperty "Namespace" "$($NamespaceName)"
                    }
                    
                    Write-BCALLog -Level VERBOSE "--Read all used namespaces of the $($ObjectType.ToLower())..." -logfile $LogFilePath
                    $RegExUsingNamespaces = 'using.?(?<UsingNamespace>[\s\S\n]*?);';
                    $UsingNamespacesNameMatches = (select-string -InputObject $FileContent -Pattern $RegExUsingNamespaces -AllMatches | ForEach-Object { $_.Matches })
                    if (![string]::IsNullOrEmpty($UsingNamespacesNameMatches)) {
                        $ALObjectUsingNamespaces = @()

                        $UsingNamespacesNameMatches | ForEach-Object {
                            $UsingNamespace = $_;

                            $ALObjectUsingNamespace = New-Object PSObject
                            Write-BCALLog -Level VERBOSE "-->$($UsingNamespace.Groups['UsingNamespace'].Value)" -logfile $LogFilePath

                            $ALObjectUsingNamespace | Add-Member NoteProperty "Namespace" "$($UsingNamespace.Groups['UsingNamespace'].Value)"
                                
                            $ALObjectUsingNamespaces += $ALObjectUsingNamespace
                        }
                        $ALObject | Add-Member NoteProperty "UsingNamespaces" $ALObjectUsingNamespaces
                    }
                    

                    #region Get Variable Blocks
                    # Get All Variable Blocks
                    Write-BCALLog -Level VERBOSE "--Read all variable declarations of the $($ObjectType.ToLower())..." -logfile $LogFilePath

                    $RegexVariableDeclarations = '(?mi)(?<=var[\r|\n])(?<Variables>[\s\S\n]+?)(?<ClosedBy>begin|(?:.*?)procedure |\})'
                    $AllVariableDeclarationMatches = select-string -InputObject $FileContent -Pattern $RegexVariableDeclarations -AllMatches | ForEach-Object { $_.Matches }
                    if (![string]::IsNullOrEmpty($AllVariableDeclarationMatches)) {
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
                                    $SubType = $Variable.Groups['SubType'].Value.ToLower();
                                    if (![string]::IsNullOrEmpty($SubType) -or ($SubType -ne ";")) {
                                        if ($ALObjectVariable.DataType -ne 'label') {
                                            # what about temp?
                                            $ALObjectVariable | Add-Member NoteProperty "SubType" "$($Variable.Groups['SubType'])"
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

                                    $ALObjectVariables += $ALObjectVariable
                                }
                            }
                        }
                        $ALObject | Add-Member NoteProperty "Variables" $ALObjectVariables
                    }
                    Write-BCALLog -Level VERBOSE "----------------------" -logfile $LogFilePath
                    #endregion

                    if (($ObjectType.ToLower() -eq 'table') -or ($ObjectType.ToLower() -eq 'tableextension')) {
                        Write-BCALLog -Level VERBOSE "--Read fields of the $($ObjectType.ToLower())..." -logfile $LogFilePath

                        $RegexField = 'field\(([0-9]*);(.*);(.*)\)[\r\n]+(.*{([^}]*)})'
                        $TableFields = select-string -InputObject $FileContent -Pattern $RegexField -AllMatches | ForEach-Object { $_.Matches }

                        Write-BCALLog -Level VERBOSE "----------------------" -logfile $LogFilePath
                        if (![string]::IsNullOrEmpty($TableFields)) {
                            $ALObjectFields = @()

                            $TableFields | ForEach-Object {
                                $Field = $_;

                                $ALObjectField = New-Object PSObject
                                Write-BCALLog -Level VERBOSE "---$($Field.Groups[1].Value) - $($Field.Groups[2].Value) - $($Field.Groups[3].Value)" -logfile $LogFilePath
                                $AlObjectFieldName = $Field.Groups[2].Value.Trim().Replace("""", "");
                                $AlFieldCode = $Field.Groups[4].Value;

                                $ALObjectField | Add-Member NoteProperty "ID" "$($Field.Groups[1].Value.ToInt32($Null))"
                                $ALObjectField | Add-Member NoteProperty "Name" "$($AlObjectFieldName)"
                                $ALObjectField | Add-Member NoteProperty "DataType" "$($Field.Groups[3].Value)"
                                $ALObjectField | Add-Member NoteProperty "Code" "$($AlFieldCode)"

                                # $RegexFieldProperties = '(\w+)(?:\s?=\s?)(.+);'
                                $RegexFieldProperties = '(?:^|\s|\t)(\w+)(?:\s?=\s?)([\s\S\n]+?);'
                                $TableFieldProperties = select-string -InputObject $AlFieldCode -Pattern $RegexFieldProperties -AllMatches | ForEach-Object { $_.Matches }

                                if (![string]::IsNullOrEmpty($TableFieldProperties)) {
                                    $ALTableFieldProperties = @()

                                    Write-BCALLog -Level VERBOSE "----Field Properties" -logfile $LogFilePath
                                    # $ALTableFieldProperty = New-Object PSObject
                                    $TableFieldProperties | ForEach-Object {
                                        $Property = $_;

                                        $ALTableFieldProperty = Add-Property -TableProperty $Property
                                        $ALTableFieldProperties += $ALTableFieldProperty

                                        $ALTableFieldProperty = Add-TableRelations -TableProperty $Property
                                        $ALTableFieldProperties += $ALTableFieldProperty

                                        $ALTableFieldProperty = Add-Calcfields -TableProperty $Property
                                        $ALTableFieldProperties += $ALTableFieldProperty
                                    }
                                }
                                # $ALObjectField | Add-Member PSObject $ALTableFieldProperties
                                $ALObjectField | Add-Member NoteProperty "Properties" $ALTableFieldProperties

                                $ALObjectFields += $ALObjectField
                            }
                            Write-BCALLog -Level VERBOSE "++++++++++++++++++++++++++" -logfile $LogFilePath


                            $ALObject | Add-Member NoteProperty "Fields" $ALObjectFields
                        }
                    }

                    if ($ObjectType.ToLower() -eq 'codeunit') {

                        Write-BCALLog -Level VERBOSE "--Read procedures of the $($ObjectType.ToLower())..." -logfile $LogFilePath

                        $RegexField = '(?mi)(?<prefix>procedure )(?<name>.*)(?<parameter>\(.*\))(?<return>.*$)(?<code>[\s\S\n]+?end;)'
                        $Procedures = select-string -InputObject $FileContent -Pattern $RegexField -AllMatches | ForEach-Object { $_.Matches }

                        
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
                                if (![string]::IsNullOrEmpty($VariablesMatches)) {
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
                                }
                                
                                #endregion
                            }

                            $ALObjectProcedures += $ALObjectProcedure
                        }
                        $ALObject | Add-Member NoteProperty "Procedures" $ALObjectProcedures
                        
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