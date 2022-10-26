<#
.SYNOPSIS
Parses Business Central AL Object Files into an Powershell Object.
.DESCRIPTION
Parses Business Central AL Object Files into an Powershell Object.
You also had more Access to Tables. Here are Fields and their Properties and Code. Additional there is an Detail Level at the "TableReleation" Property.
.Parameter SourceFilePath
This is the root path of the AL Files.
.EXAMPLE
Get-BCALObjects "C:\temp\ALProject\App\src"
.EXAMPLE
Get-BCALObjects "C:\temp\ALProject\App\src" | Where-Object Type -eq "table"
.EXAMPLE
Get-BCALObjects "C:\temp\ALProject\App\src" -Verbose | Where-Object {($_.Type -eq "table")} | Select-Object Type, ID
.EXAMPLE
Get-BCALObjects "C:\temp\ALProject\App\src" | Where-Object {($_.Type -eq "table")} | Select-Object Type, ID, Path
.EXAMPLE
Get-BCALObjects "C:\temp\ALProject\App\src" -verbose| Where-Object {($_.Type -eq "table")} | Select-Object Type, ID, Path
.EXAMPLE
Get-BCALObjects "C:\temp\ALProject\App\src" | Where-Object {($_.Type -eq "table") -and ($_.ID -eq 50120)} | Select-Object Type, ID, Path
#>
function Get-BCALObjects {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourceFilePath
    )

    begin {
        . (Join-Path $PSScriptRoot "\utils\Add-TableRelations.ps1")
        . (Join-Path $PSScriptRoot "\utils\Add-Property.ps1")
        . (Join-Path $PSScriptRoot "\utils\Add-Calcfields.ps1")

        $ALObjects = @()
    }

    process {
        Write-Verbose "SourceFilePath $($SourceFilePath)"

        $filter = "*.al"

        Write-Verbose "Filter files with '$($filter)'"

        Get-ChildItem $SourceFilePath -Filter $filter -Recurse | ForEach-Object {
            $CurrFile = $_;
            Write-Verbose "$($CurrFile.Fullname)"
            Write-Verbose "Path is available:$($(Test-Path $CurrFile.Fullname))"

            $file = Get-Item $SourceFilePath -Force -ea SilentlyContinue
            $isSymLink = [bool]($file.Attributes -band [IO.FileAttributes]::ReparsePoint)
            Write-Verbose "Path is Symlink:$($isSymLink)"

            if ((Test-Path $_.Fullname) -and (!$isSymLink)) {

                ## TODO: Ginge sicher auch mit regex :)
                [string]$FileContent = Get-Content -Path $CurrFile.FullName -Raw
                if (![string]::IsNullOrEmpty($FileContent)) {
                    Write-Verbose "Object found: '$($CurrFile.FullName)'"

                }

                # Get Object ObjectType, ID, Name 
                # $regex = '^(\w+)\s(\d*)\s"(.*)"'
                $regex = '(\w+)\s(\d*)\s"(.*?)"(?:\s(extends)\s"(.*)")?'

                $FileContentObject = select-string -InputObject $FileContent -Pattern $regex -AllMatches | ForEach-Object { $_.Matches }

                if ([string]::IsNullOrEmpty($FileContentObject)) {
                    Write-Warning "File Found but Object not recognized!"
                    Write-Warning "File: $($CurrFile.FullName)"
                }


                $AlObject = $null;
                if (![string]::IsNullOrEmpty($FileContentObject)) {

                    Write-Verbose "Object ID found: '$($FileContentObject)'"
                    Write-Verbose  "->$($FileContentObject)"

                    $ObjectType = $FileContentObject.Groups[1].Value;

                    $ALObject = New-Object PSObject
                    $ALObject | Add-Member NoteProperty "Type" "$($ObjectType.ToLower())"
                    $ALObject | Add-Member NoteProperty "ID" "$($FileContentObject.Groups[2].Value)"
                    $ALObject | Add-Member NoteProperty "Name" "$($FileContentObject.Groups[3].Value)"
                    $ALObject | Add-Member NoteProperty "Path" "$($CurrFile.FullName)"
                    $ALObject | Add-Member NoteProperty "Extends" "$($FileContentObject.Groups[5].Value)"
                    # $ALObject | Add-Member NoteProperty "Object" "$($FileContent)"



                    if ($ObjectType.ToUpper() -eq 'TABLE') {
                        Write-Verbose "--Read fields of the table..."

                        $RegexField = 'field\(([0-9]*);(.*);(.*)\)[\r\n]+(.*{([^}]*)})'
                        $TableFields = select-string -InputObject $FileContent -Pattern $RegexField -AllMatches | ForEach-Object { $_.Matches }

                        Write-Verbose "----------------------"
                        if (![string]::IsNullOrEmpty($TableFields)) {
                            $ALObjectFields = @()

                            $TableFields | ForEach-Object {
                                $Field = $_;

                                $ALObjectField = New-Object PSObject
                                Write-Verbose "---$($Field.Groups[1].Value) - $($Field.Groups[2].Value) - $($Field.Groups[3].Value)"
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

                                    Write-Verbose "----Field Properties"
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
                            Write-Verbose "++++++++++++++++++++++++++"


                            $ALObject | Add-Member NoteProperty "Fields" $ALObjectFields
                        }
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