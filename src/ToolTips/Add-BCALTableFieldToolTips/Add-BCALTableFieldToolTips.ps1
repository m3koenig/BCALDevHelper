# TODO: Update Tooltip. Not only add
# TODO: not only a german replacement of the default translation (XLIF Comments)
function Add-BCALTableFieldToolTips {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourceFilePath,
        [string]$LanguageCode,
        [string]$LogFilePath
    )

    begin {}

    process {
        Write-BCALLog -Level VERBOSE "SourceFilePath $($SourceFilePath)" -logfile $LogFilePath

        $filter = "*.al"
        Write-BCALLog -Level VERBOSE "Filter files with '$($filter)'" -logfile $LogFilePath

        $ALFiles = @(Get-ChildItem $SourceFilePath -Filter $filter -Recurse)
        $ALFiles | ForEach-Object {
            $CurrFile = $_;
            Write-BCALLog -Level VERBOSE "$($CurrFile.Fullname)" -logfile $LogFilePath
            Write-BCALLog -Level VERBOSE "Path is available:$($(Test-Path $CurrFile.Fullname))" -logfile $LogFilePath

            $file = Get-Item $SourceFilePath -Force -ea SilentlyContinue
            $isSymLink = [bool]($file.Attributes -band [IO.FileAttributes]::ReparsePoint)
            Write-BCALLog -Level VERBOSE "Path is Symlink:$($isSymLink)" -logfile $LogFilePath

            if ((Test-Path $_.Fullname) -and (!$isSymLink)) {
                # Get Content
                [string]$FileContent = Get-Content -Path $CurrFile.FullName -Raw
                if (![string]::IsNullOrEmpty($FileContent)) {
                    Write-BCALLog -Level VERBOSE "Object found: '$($CurrFile.FullName)'" -logfile $LogFilePath
                }                
                $newContent = $FileContent
                
                #region Handle Object Type
                [string]$regex = Get-BCALRegExObjectDefinition;
                $FileContentObject = select-string -InputObject $newContent -Pattern $regex -AllMatches | ForEach-Object { $_.Matches }

                if ([string]::IsNullOrEmpty($FileContentObject)) {
                    Write-BCALLog -Level WARN "File Found but Object not recognized!" -logfile $LogFilePath
                    Write-BCALLog -Level WARN "File: $($CurrFile.FullName)" -logfile $LogFilePath
                }      
                
                if (![string]::IsNullOrEmpty($FileContentObject)) {

                    Write-BCALLog -Level VERBOSE "Object ID found: '$($FileContentObject)'" -logfile $LogFilePath
                    Write-BCALLog -Level VERBOSE  "->$($FileContentObject)" -logfile $LogFilePath

                    $ObjectType = $FileContentObject.Groups['Type'].Value;
                }

                if (($ObjectType.ToLower() -ne 'table') -and ($ObjectType.ToLower() -ne 'tableextension')) {
                    Write-BCALLog -Level VERBOSE "This is not a table (or extension). This function is for table(extension) field!" -logfile $LogFilePath
                    continue
                }
                #endregion
                

                #region New Field Code
                $RegExField = "(?<FieldCodeStart>(?<CodeSummary>\/\/\/\s\<summary\>(?<SummaryValue>[\s\S\n]*?)\/\/\/\s\<\/summary>(?<SummaryDetails>[\s\S\n]*?))?(?<Field>field\((?<FieldId>[0-9]*);(?<FieldName>.*);(?<FieldDataType>.*)\)[\n\s\S]*?{))(?<FieldContent>[\s\n\S]*?)(?<FieldCodeEnd>})"
                $newContent = [regex]::Replace($newContent, $RegexField, { param($CurrMatch) 
                        Write-BCALLog -Level VERBOSE "-->Field: $($CurrMatch.Groups['FieldName'].Value)" -logfile $LogFilePath
                        Write-BCALLog -Level VERBOSE "-->Field Match: $($CurrMatch)" -logfile $LogFilePath
                        $NewFieldCode = $CurrMatch;

                        $FieldName = $CurrMatch.Groups['FieldName'].Value.Trim()
        

                        #$RegExFieldContent = "(?<PropertyLine>(?<Property>\w+)(?:\s?=\s?)(?<Value>[\s\S\n]+?);)"         
                        $FieldCodeStart = $CurrMatch.Groups['FieldCodeStart'].Value
                        $FieldContent = $CurrMatch.Groups['FieldContent'].Value
                        $FieldCodeEnd = "        $($CurrMatch.Groups['FieldCodeEnd'].Value)"
                
                        # Trim whitespace and linefeeds
                        $FieldContent = $FieldContent -replace '([\s\n]*?)$', ''
                        $FieldContent = $FieldContent -replace '(^\n?(?<SpaceIndention>[\s]*))', "            "

                        #region Get Caption and Comment
                        $CaptionTranslation = '';
                        if (![string]::IsNullOrEmpty($LanguageCode)) {
                            $RegExCaptionProperty = '(?<PropertyLine>(?<Property>Caption)(?:\s?=\s?)''(?<Value>[\s\S\n]+?)''[,|;](?<Comment> Comment = ''(?<CommentValue>[\s\S\n]+?)'')?)'
                            $CaptionProperty = select-string -InputObject $FieldContent -Pattern $RegExCaptionProperty -AllMatches | ForEach-Object { $_.Matches }
                            if ($null -ne $CaptionProperty) {
                                Write-BCALLog -Level VERBOSE "--->CaptionProperty: $($CaptionProperty)" -logfile $LogFilePath
                                $CommentValue = $CaptionProperty[0].Groups['CommentValue'].Value;                            
                                if ($null -ne $CommentValue) {
                                    if ($CommentValue -match "($LanguageCode=(.*))") {
                                        Write-BCALLog -Level VERBOSE "--->existing '$($LanguageCode)' comment!" -logfile $LogFilePath
                                        $CommentTranslation = select-string -InputObject $CommentValue -Pattern "($LanguageCode=(?<TranslationValue>.*))" -AllMatches | ForEach-Object { $_.Matches }
                                        if ($null -ne $CommentTranslation) {
                                            Write-BCALLog -Level VERBOSE "--->'$($LanguageCode)' comment: $($CommentTranslation[0].Groups['TranslationValue'].Value)" -logfile $LogFilePath
                                            $CaptionTranslation = $CommentTranslation[0].Groups['TranslationValue'].Value;
                                        }                                    
                                    }
                                }
                            }
                        }
                        #endregion
                
                        $ToolTip = "            ToolTip = 'Specifies the value of the ""$($FieldName)"" field.'"
                        if (![string]::IsNullOrEmpty($CaptionTranslation)) {
                            # TODO: Only german??.....
                            if ($LanguageCode.ToLower() -eq "de-de") {
                            $ToolTip += ", Comment = '$LanguageCode=Gibt den Wert des Feldes ""$($CaptionTranslation)"" an.'";
                            }else {
                                $ToolTip += ", Comment = '$LanguageCode=Specifies the value of the ""$($CaptionTranslation)"" field.'";
                            }
                        }
                        $ToolTip += ";";

                        $NewFieldCode = @"
$FieldCodeStart
$FieldContent
$ToolTip
$FieldCodeEnd
"@
                
                        return $NewFieldCode                        
                    })
                #endregion

                $newContent | Out-File -FilePath $CurrFile.FullName -NoNewline -Force 
            }
        }

    }

    end {}    
}
Export-ModuleMember -Function Add-BCALTableFieldToolTips