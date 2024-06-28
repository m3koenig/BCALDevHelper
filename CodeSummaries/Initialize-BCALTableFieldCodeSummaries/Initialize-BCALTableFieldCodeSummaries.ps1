# TODO: Refactoring. Not nice. Should be reworked.
function Initialize-BCALTableFieldCodeSummaries {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourceFilePath,

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
                
                #region Is Table/Ext
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

                #region Add Dummy Summary if missing any
                
                Write-BCALLog -Level VERBOSE "-->Add Dummy Summary for the field." -logfile $LogFilePath
                [string]$RegExForPreFieldCode = "(?<SpaceBetween>[}|{][\s\n]*?)(?<Field>field[^sg])"
                $replacement = @'
${SpaceBetween}
        /// <summary>
        /// </summary>
        ${Field}
'@
                $newContent = $newContent -replace $RegExForPreFieldCode, $replacement     
                #endregion

                #region Build Summary
                $RegexField = "(?<CodeSummary>\/\/\/\s\<summary\>(?<SummaryValue>[\s\S\n]*?)\/\/\/\s\<\/summary>(?<SummaryDetails>[\s\S\n]*?))?(?<Field>field\((?<FieldId>[0-9]*);(?<FieldName>.*);(?<FieldDataType>.*)\)[\n\s\S]*?{(?<FieldContent>[\s\n\S]*?)})";
                $newContent = [regex]::Replace($newContent, $RegexField, { param($CurrMatch) 
                        Write-BCALLog -Level VERBOSE "-->Field: $($CurrMatch.Groups['FieldName'].Value)" -logfile $LogFilePath
                        Write-BCALLog -Level VERBOSE "-->Field Code Summary Match: $($CurrMatch)" -logfile $LogFilePath
                        $newGroupContent = $CurrMatch;

                        $FieldContent = $CurrMatch.Groups['FieldContent'].Value
                        $NewSummary = '';

                        #region Get FieldClass
                        $RegExFieldClassProperty = '(?<PropertyLine>(?<Property>FieldClass)(?:\s?=\s?)('')?(?<Value>[\s\S\n]+?)('')?;)'
                        $FieldClassProperty = select-string -InputObject $FieldContent -Pattern $RegExFieldClassProperty -AllMatches | ForEach-Object { $_.Matches }
                        $ProperyFieldClassValue = "";
                        if ($null -ne $FieldClassProperty) {
                            $ProperyFieldClassValue = $FieldClassProperty[0].Groups['Value'].Value;
                            Write-BCALLog -Level VERBOSE "--->FieldClass: $($ProperyFieldClassValue)" -logfile $LogFilePath
                            # only show not "Normal" fields
                            if ($ProperyFieldClassValue.ToLower() -ne "normal") { 
                                $ProperyFieldClassValue = "$($ProperyFieldClassValue)" 
                            }
                            else {
                                $ProperyFieldClassValue = "";
                            }
                        }
                        #endregion

                        #region Get Caption    
                        $RegExCaptionProperty = '(?<PropertyLine>(?<Property>Caption)(?:\s?=\s?)''(?<Value>[\s\S\n]+?)''[,|;](?<Comment> Comment = ''(?<CommentValue>[\s\S\n]+?)'')?)'
                        $CaptionProperty = select-string -InputObject $FieldContent -Pattern $RegExCaptionProperty -AllMatches | ForEach-Object { $_.Matches }
                        if ($null -ne $CaptionProperty) {
                            Write-BCALLog -Level VERBOSE "--->CaptionProperty: $($CaptionProperty)" -logfile $LogFilePath
                            $CaptionPropertyValue = $CaptionProperty[0].Groups['Value'].Value;
                            $CaptionPropertyCommentValue = $CaptionProperty[0].Groups['CommentValue'].Value;                            
                        }
                        #endregion

                        #region Get Description
                        $RegExDescriptionProperty = '(?<PropertyLine>(?<Property>Description)(?:\s?=\s?)''(?<Value>[\s\S\n]+?)'';)'
                        $DescriptionProperty = select-string -InputObject $FieldContent -Pattern $RegExDescriptionProperty -AllMatches | ForEach-Object { $_.Matches }
                        if ($null -ne $DescriptionProperty) {
                            $ProperyDescriptionValue = $DescriptionProperty[0].Groups['Value'].Value;
                            Write-BCALLog -Level VERBOSE "--->ProperyDescriptionValue: $($ProperyDescriptionValue)" -logfile $LogFilePath
                        }
                        #endregion

                        $CurrentSummaryValue = $CurrMatch.Groups['SummaryValue'].Value

                        $SynopsisInit = @"

                        /// ---
                        /// *<b>Synopsis:</b>
"@
                        $SynopsisSuffix = "*";

                        $RegExSynopsis = '\n(?:[\s]*?)(?<Synopsis>[\s\/]* ---(?:[\s\S]*?)(?<SynopsisPrefix>\*<b>Synopsis:<\/b> )(?<SynopsisValue>(?:[\s\S]*?))(?<SynopsisSuffix>\*?)$)'
                        $SynopsisMatch = select-string -InputObject $CurrentSummaryValue -Pattern $RegExSynopsis -AllMatches | ForEach-Object { $_.Matches }
                        $CurrentSynopsis = ""
                        if ($null -ne $SynopsisMatch) {
                            $CurrentSynopsis = $SynopsisMatch[0].Groups['Synopsis'].Value;
                        }

                        # $CurrMatch.Groups['FieldName'].Value
                        # $CurrMatch.Groups['Field'].Value
                        # $newGroupContent = @"
                        # /// <summary>$($CurrMatch.Groups['SummaryValue'].Value)$($NewSummary)
                        #         /// </summary>$($CurrMatch.Groups['SummaryDetails'].Value)$($CurrMatch.Groups['Field'].Value)
                        # "@
                        return $newGroupContent
                    })
                #endregion

                $newContent | Out-File -FilePath $CurrFile.FullName -NoNewline -Force 
            }
        }

    }

    end {}    
}
Export-ModuleMember -Function Initialize-BCALTableFieldCodeSummaries