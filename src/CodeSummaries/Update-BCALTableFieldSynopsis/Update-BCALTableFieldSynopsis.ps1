<#
.SYNOPSIS
    Updates XML documentation comments for table or table extension fields in AL files. It adds a "synopsis" under the regular summary.
.DESCRIPTION
    Processes AL files in a specified directory to add or update summary comments for each table or table extension field. It scans files, identifies tables or table extensions, and ensures each field has a formatted summary including metadata such as caption, description, and field class. The updated content is saved back to the original files.
    It will add the so called "synopsis" seperated with a line under the regular summary.
    It will try to provide this structre:
    > <Caption> / <Caption Comment> / <Description: DescriptionValue> / <Field Class if not normal>
.PARAMETER SourceFilePath
    The path to the directory containing AL files to process. Could also be one lonesome file.
.PARAMETER LogFilePath
    The path to the log file for verbose logging.
.EXAMPLE
    Update-BCALTableFieldSynopsis -SourceFilePath "C:\Source\BCALFiles"
.EXAMPLE
    Update-BCALTableFieldSynopsis -SourceFilePath "C:\Source\BCALFiles" -LogFilePath "C:\Logs\BCALUpdate.log"
#>
function Update-BCALTableFieldSynopsis {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourceFilePath,

        [string]$LogFilePath
    )

    begin {}

    process {
        $NewLine = "`n";
        Write-BCALLog -Level VERBOSE "SourceFilePath $($SourceFilePath)" -logfile $LogFilePath

        $filter = "*.al"
        Write-BCALLog -Level VERBOSE "Filter files with '$($filter)'" -logfile $LogFilePath

        $ALFiles = @(Get-ChildItem $SourceFilePath -Filter $filter -Recurse)
        $ALFiles | ForEach-Object {
            $CurrFile = $_;
            $skipFile = $false;
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
                
                $ObjectType = '';
                if (![string]::IsNullOrEmpty($FileContentObject)) {

                    Write-BCALLog -Level VERBOSE "Object ID found: '$($FileContentObject)'" -logfile $LogFilePath
                    Write-BCALLog -Level VERBOSE  "->$($FileContentObject)" -logfile $LogFilePath

                    $ObjectType = $FileContentObject.Groups['Type'].Value;
                }

                if (($ObjectType.ToLower() -ne 'table') -and ($ObjectType.ToLower() -ne 'tableextension')) {
                    Write-BCALLog -Level VERBOSE "This is not a table (or extension). This function is for table(extension) field!" -logfile $LogFilePath
                    $skipFile = $true;
                }
                #endregion

                if (!$skipFile) {
    
                    #region Add Dummy Summary if missing any
                    Write-BCALLog -Level VERBOSE "-->Add Dummy Summary for the field." -logfile $LogFilePath
                    [string]$RegExForPreFieldCode = "(?<SpaceBetween>[}|{][\s\n]*?)(?<Field>field[^sg][\d])"
                    $replacement = @'
${SpaceBetween}
        /// <summary>
        /// </summary>
        ${Field}
'@
                    $newContent = $newContent -replace $RegExForPreFieldCode, $replacement     
                    #endregion
    
                    #region Build Summary with Field Metadata
                    $RegexField = "(?<CodeSummary>(?:\s)\/{3}\s\<summary\>(?<SummaryValue>[\s\S\n]*?)\/{3}\s\<\/summary>(?<SummaryDetails>[\s\S\n]*?))?(?<Field>field\((?<FieldId>[0-9]*);(?<FieldName>.*);(?<FieldDataType>.*)\)[\n\s\S]*?{(?<FieldContent>[\s\n\S]*?)})";
                    $newContent = [regex]::Replace($newContent, $RegexField, { param($CurrMatch) 
                            Write-BCALLog -Level VERBOSE "-->Field: $($CurrMatch.Groups['FieldName'].Value)" -logfile $LogFilePath
                            Write-BCALLog -Level VERBOSE "-->Field Code Summary Match: $($CurrMatch)" -logfile $LogFilePath
                            $newGroupContent = $CurrMatch;
                            $CurrentSummaryValue = $CurrMatch.Groups['SummaryValue'].Value
                            Write-BCALLog -Level VERBOSE "-->Current Summary Value: $($CurrentSummaryValue)"

                            $FieldName = $CurrMatch.Groups['FieldName'].Value
                            $FieldContent = $CurrMatch.Groups['FieldContent'].Value                        
    
                            #region Get FieldClass
                            Write-BCALLog -Level VERBOSE "-->Get FieldClass..." -logfile $LogFilePath
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
                            Write-BCALLog -Level VERBOSE "-->Get Caption..." -logfile $LogFilePath
                            $RegExCaptionProperty = '(?<PropertyLine>(?<Property>Caption)(?:\s?=\s?)''(?<Value>[\s\S\n]+?)''[,|;](?<Comment> Comment = ''(?<CommentValue>[\s\S\n]+?)'')?)'
                            $CaptionProperty = select-string -InputObject $FieldContent -Pattern $RegExCaptionProperty -AllMatches | ForEach-Object { $_.Matches }
                            $CaptionPropertyValue = "";
                            $CaptionPropertyCommentValue = "";
                            if ($null -ne $CaptionProperty) {
                                Write-BCALLog -Level VERBOSE "--->CaptionProperty: $($CaptionProperty)" -logfile $LogFilePath
                                $CaptionPropertyValue = $CaptionProperty[0].Groups['Value'].Value;
                                $CaptionPropertyCommentValue = $CaptionProperty[0].Groups['CommentValue'].Value;                            
                            }
                            #endregion
    
                            #region Get Description
                            Write-BCALLog -Level VERBOSE "-->Get Description..." -logfile $LogFilePath
                            $RegExDescriptionProperty = '(?<PropertyLine>(?<Property>Description)(?:\s?=\s?)''(?<Value>[\s\S\n]+?)'';)'
                            $DescriptionProperty = select-string -InputObject $FieldContent -Pattern $RegExDescriptionProperty -AllMatches | ForEach-Object { $_.Matches }
                            $ProperyDescriptionValue = "";
                            if ($null -ne $DescriptionProperty) {
                                $ProperyDescriptionValue = $DescriptionProperty[0].Groups['Value'].Value;
                                Write-BCALLog -Level VERBOSE "--->ProperyDescriptionValue: $($ProperyDescriptionValue)" -logfile $LogFilePath
                            }
                            #endregion
    
                            $SynopsisInit = @"
        /// 
        /// ---
        /// ***Synopsis:** 
"@
                            $SynopsisSuffix = "*";   
    
                            #region Remove prev. synopsis
                            Write-BCALLog -Level VERBOSE "-->Remove prev. synopsis..." -logfile $LogFilePath
                            $RegExSynopsis = '(?<SynopsisInit>(?:[\s]*\/{3}){2} ---(?:[\s\S]*?)(?<SynopsisPrefix>\*{3}Synopsis:\*{2} ))(?<SynopsisValue>([\s\S]*?))(?<SynopsisSuffix>\*?)$'
                            
                            Write-BCALLog -Level VERBOSE "-->CurrentSummaryValue '$($CurrentSummaryValue)'" -logfile $LogFilePath
                            Write-BCALLog -Level VERBOSE "-->RegExSynopsis '$($RegExSynopsis)'" -logfile $LogFilePath
                            $SynopsisMatch = [regex]::Replace($CurrentSummaryValue, $RegExSynopsis, { param($CurrSynopsis)
                                    Write-BCALLog -Level VERBOSE "--->Replace current synopsis: '$($CurrSynopsis)'" -logfile $LogFilePath
                                    $NewSynopsis = ""
                                    return $NewSynopsis
                                });
                            Write-BCALLog -Level VERBOSE "-->Get the Synopsis Match: '$($SynopsisMatch)'" -logfile $LogFilePath
                            # Remove new lines at the start
                            $SynopsisMatch = $SynopsisMatch -replace '^[\r\n]*'
                            # Trim last CR and spaces
                            $SynopsisMatch = $SynopsisMatch -replace '(\n)[\s]*?$\z'
                            # Remove if only whitespaces (e.g. empty summary or not exists)
                            $SynopsisMatch = $SynopsisMatch -replace '\A\s*\z'
    
                            Write-BCALLog -Level VERBOSE "-->New Init Summary (Synopsis will be added now): '$($SynopsisMatch)'" -logfile $LogFilePath
                            
                            $SynopsisMatch += "$($SynopsisInit)";                            
                            
                            if (![string]::IsNullOrEmpty($CaptionPropertyValue)) {
                                $SynopsisMatch += "$($CaptionPropertyValue)"

                                if (![string]::IsNullOrEmpty($CaptionPropertyCommentValue)) {
                                    $SynopsisMatch += " / $($CaptionPropertyCommentValue)"
                                }
                            }
    
                            if (![string]::IsNullOrEmpty($ProperyDescriptionValue)) {
                                if (![string]::IsNullOrEmpty($SynopsisMatch)) {
                                    $SynopsisMatch += " / "
                                }
                                $SynopsisMatch += "Description: $($ProperyDescriptionValue)"
                            }

                            
                            if (![string]::IsNullOrEmpty($ProperyFieldClassValue)) {
                                if (![string]::IsNullOrEmpty($SynopsisMatch)) {
                                    $SynopsisMatch += " / "
                                }
                                $SynopsisMatch += "$($ProperyFieldClassValue)"
                            }    
                            
    
                            $SynopsisMatch += $SynopsisSuffix
                            #endregion
                                                     
    
                            $NewSummaryContent = $SynopsisMatch;
                            Write-BCALLog -Level VERBOSE "--->New Summary with Synopsis: $($NewLine)$($NewSummaryContent)"
    
                            # (?:\s)
                            $newGroupContent = " /// <summary>$($NewLine)";
                            if (![string]::IsNullOrEmpty($NewSummaryContent)) {
                                $newGroupContent += "$($NewSummaryContent)$($NewLine)"
                            }
                            $newGroupContent += "        /// </summary>$($CurrMatch.Groups['SummaryDetails'].Value)$($CurrMatch.Groups['Field'].Value)"
    
                            return $newGroupContent
                        })
                    #endregion
    
                    $newContent | Out-File -FilePath $CurrFile.FullName -NoNewline -Force 
                }
            }
        }

    }

    end {}    
}
Export-ModuleMember -Function Update-BCALTableFieldSynopsis