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

        Get-ChildItem $SourceFilePath -Filter $filter -Recurse | ForEach-Object {
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
                $regex = '(\w+)\s(\d*)\s"(.*?)"(?:\s(extends)\s"(.*)")?'

                $FileContentObject = select-string -InputObject $FileContent -Pattern $regex -AllMatches | ForEach-Object { $_.Matches }

                if ([string]::IsNullOrEmpty($FileContentObject)) {
                    Write-BCALLog -Level WARN "File Found but Object not recognized!" -logfile $LogFilePath
                    Write-BCALLog -Level WARN "File: $($CurrFile.FullName)" -logfile $LogFilePath
                }


                $AlObject = $null;
                if (![string]::IsNullOrEmpty($FileContentObject)) {

                    Write-BCALLog -Level VERBOSE "Object ID found: '$($FileContentObject)'" -logfile $LogFilePath
                    Write-BCALLog -Level VERBOSE  "->$($FileContentObject)" -logfile $LogFilePath

                    $ObjectType = $FileContentObject.Groups[1].Value;

                    $ALObject = New-Object PSObject
                    $ALObject | Add-Member NoteProperty "Type" "$($ObjectType.ToLower())"
                    $ALObject | Add-Member NoteProperty "ID" "$($FileContentObject.Groups[2].Value)"
                    $ALObject | Add-Member NoteProperty "Name" "$($FileContentObject.Groups[3].Value)"
                    $ALObject | Add-Member NoteProperty "Path" "$($CurrFile.FullName)"
                    $ALObject | Add-Member NoteProperty "Extends" "$($FileContentObject.Groups[5].Value)"
                    # $ALObject | Add-Member NoteProperty "Object" "$($FileContent)"



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

                        $RegexField = '(?mi)(?<prefix>procedure )(?<name>.*)(?<parameter>\(.*\))(?<return>.*$)'
                        $Procedures = select-string -InputObject $FileContent -Pattern $RegexField -AllMatches | ForEach-Object { $_.Matches }

                        
                        $ALObjectProcedures = @()

                        $Procedures | ForEach-Object {
                          $Procedure = $_;
                          
                          Write-BCALLog -Level VERBOSE "---$($Procedure.Groups['name'])" -logfile $LogFilePath
                          $ALObjectProcedure = New-Object PSObject
                          $ALObjectProcedure | Add-Member NoteProperty "Name" "$($Procedure.Groups['name'])"
                          $ALObjectProcedure | Add-Member NoteProperty "parameter" "$($Procedure.Groups['parameter'])"
                          $ALObjectProcedure | Add-Member NoteProperty "return" "$($Procedure.Groups['return'])"

                          
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