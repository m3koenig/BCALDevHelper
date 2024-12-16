<#
.SYNOPSIS
    Will add the translation from the XLIFF file to the AL source code as a comment.
.DESCRIPTION
    Will loop through all AL files in the given directory and search for the Source (Caption, Label, ToolTip) in the XLIFF file. The found translation will be added as a comment to the AL source code.
    It will check if the property already has a comment and if it has the comment in the language code. If it has the comment in the language code it will replace the existing comment with the new one. If it has no comment it will append the new comment to the property.
    The first translation found in the XLIFF file will be used.
.PARAMETER SrcDirectory
    The directory where the AL files are located.
.PARAMETER XliffFilePath
    The path to the XLIFF file that contains the translations.
.PARAMETER AddTranslationOptions
    Add all found transalation options from the xlf that fitts to the source as a comment region.
.Parameter copyFromSource
    Specifies whether translations should be copied from the source text (note: only when there is not already an existing translation in the target).
.PARAMETER LogFilePath
    The path to the log file. If its not set the log will be written to the console.
.PARAMETER simulate
    You want to check the result without changing the files? Set this switch and the script will only log the changes it would do. Its recommended to set the LogFilePath parameter to a file.
.NOTES
    If there are a translateable property, that is splitted over more than one line, it will not translated or updated. Or in clear words: This could cause errors!
.EXAMPLE
    $ALFiles = "C:\Projects\BC\AL\Customer\App\src"
    $XMLFile = "C:\Projects\BC\AL\Customer\App\translations\Customer.de-DE.xlf"
    $LogFile = Join-Path $env:TEMP "Sync-BCALTransunitTargetsToXliffSyncComment.log"
    Sync-BCALTransunitTargetsToXliffSyncComment -SrcDirectory $ALFiles -XLIFFFilePath $XMLFile -LogFilePath $LogFile
#>
function Sync-BCALTransunitTargetsToXliffSyncComment {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$SrcDirectory,
        
        [Parameter(Mandatory = $true)]
        [string]$XliffFilePath,

        [switch]$AddTranslationOptions,

        [switch]$copyFromSource,

        [string]$LogFilePath,

        [switch]$simulate

    )
    
    begin {
        . (Join-Path $PSScriptRoot "utils\Sync-BCALCommentPropertyTranslation.ps1")
    }


    process {
        if (![string]::IsNullOrEmpty($LogFilePath)) {
            Write-BCALLog "---------------------------------------------------" -logfile $LogFilePath
        }
        $startDate = Get-Date
        Write-BCALLog "Start: $($startDate)" -logfile $LogFilePath

        
        Write-BCALLog "Load xlf '$($XliffFilePath)'" -Level VERBOSE
        $transUnits = Get-BCALXliffAsArray -XliffFilePath $XliffFilePath -LogFilePath $LogFilePath -copyFromSource:$copyFromSource        
        Write-BCALLog "transUnit Count: $($transUnits.Count)" -Level VERBOSE

        Write-BCALLog "Load AL source path '$($SrcDirectory)'" -Level VERBOSE
        $files = Get-ChildItem $SrcDirectory -Filter *.al -Recurse

        if ($files -is [array]) { 
            $fileCount = $files.Count;
        }
        else {
            $fileCount = 1;
        }        
        Write-BCALLog "AL Fields: $($fileCount)" -Level VERBOSE
        
        $currFile = 0;
        $changedPropertyComment = 0;
        $changedFiles = 0;
        foreach ($file in $files) {
            $currFile++
            $contentChanged = $false
            Write-BCALLog ">Object ($($currFile)/$($fileCount)) $($file.FullName)" -logfile $LogFilePath

            $currFilePercent = ($currFile / $fileCount) * 100;
            $currFilePercent = [math]::Round($currFilePercent)
            $content = Get-Content $file.FullName -Encoding UTF8
            Write-BCALLog "->Object Content: $($content.Length) lines" -logfile $LogFilePath

            $RegexToTranslate = '(?mi)(?<Type>(?: Caption )|(?: Label )|(?: ToolTip)|(?: OptionCaption ))(?:=?.?'')(?<ToTranslate>.*?)(?:'')'
            $fileContentTranslatables = select-string -InputObject $content -Pattern $RegexToTranslate -AllMatches | ForEach-Object { $_.Matches }
            Write-BCALLog "->translatable: $($fileContentTranslatables)" -logfile $LogFilePath
            
            
            if ($fileContentTranslatables -isnot [array]) { 
                $fileContentTranslatables = @($fileContentTranslatables)
            }
            $TranslatablePropertyCount = $fileContentTranslatables.Count
            # TODO: ERROR HIER IST WAS FALSCH!!

            $ProgressFileTitle = "($($currFile)/$($fileCount)) - $($file.Basename)";
            Write-Progress -Activity $ProgressFileTitle -Status "$currFilePercent% Complete:" -PercentComplete $currFilePercent
            Write-BCALLog "->translatable properties: $($TranslatablePropertyCount)" -logfile $LogFilePath

            if ($TranslatablePropertyCount -eq 0) { Continue; }

            $NewContent = New-Object System.Collections.Generic.List[System.Object]
            $fileLineCount = $content.Length;
            # Loop tru lines of the file
            for ($fileLineNo = 0; $fileLineNo -lt $fileLineCount; $fileLineNo++) {
                if ($fileLineNo % 50 -eq 0) {
                    $ProgressLineTitle = "Line ($($fileLineNo)/$($fileLineCount))";
                    Write-Progress -Activity $ProgressFileTitle  -Status "Total $currFilePercent% - $($ProgressLineTitle):" -PercentComplete $currFilePercent
                }
                $currentLine = $content[$fileLineNo];
                $currentLineToTranslate = ''
                $currentLineToTranslate = select-string -InputObject $currentLine -Pattern $RegexToTranslate -AllMatches | ForEach-Object { $_.Matches }

                if ([string]::IsNullOrEmpty($currentLineToTranslate)) {
                    $NewContent.Add($currentLine);
                }
                else {
                    $toTranslate = $currentLineToTranslate.Groups['ToTranslate'];
                    $transUnit = $transUnits | Where-Object { ($_.Source -eq $toTranslate) -and ($null -ne $_.Target) -and ($null -ne $_.TargetLanguage) -and ($_.Target -ne "") }                   
                    Write-BCALLog "->Line: $($currentLineToTranslate)" -logfile $LogFilePath
                    Write-BCALLog "-->Source: $($toTranslate)" -logfile $LogFilePath
                
                    $transUnitExist = $false;
                    $transUnitOptionCount = 1;
                    $NewTranslation = $null;
                    if ($transUnit -is [array]) {
                        # Found multiple translations!
                        $transUnitOptions = $transUnit | Group-Object Source, Target | ForEach-Object { $_.Group } | Select-Object Source, Target | Sort-Object Target | Get-Unique -AsString                        
                        $transUnitOptionCount = $transUnitOptions.Count;
                        $transUnitExist = $transUnitOptionCount -gt 0;
                        if ($transUnitExist) {
                            Write-BCALLog "-->Translations found (will pick first of xlf transunit entry): $($transUnitOptions.Count)" -logfile $LogFilePath
                            $NewTranslation = [string]$transUnit[0].Target
                            $LanguageCode = [string]$transUnit[0].TargetLanguage

                            # TODO: How to get, if one of the options is my current translation?! 
                            # TODO: $LanguageCode ...
                            $transUnitOptions | ForEach-Object {
                                $CheckLine = Sync-BCALCommentPropertyTranslation -PropertyLine $currentLine -LanguageCode $LanguageCode -NewTranslation $_.Target -LogFilePath $LogFilePath
                                if ($content[$fileLineNo] -eq $CheckLine) {
                                    Write-BCALLog "--->Found Translation in the options: $($_.Target)" -logfile $LogFilePath
                                    $NewTranslation = $_.Target;
                                }
                            }
                        }
                    }
                    else {
                        $transUnitExist = $null -ne $transUnit;
                        if ($transUnitExist) {
                            Write-BCALLog "-->Translation found: $($transUnit.Target)" -logfile $LogFilePath
                            $NewTranslation = [string]$transUnit.Target
                            $LanguageCode = [string]$transUnit.TargetLanguage
                        }
                    }
                
                    if ($transUnitExist) {
                        $NewTranslation = $NewTranslation.Replace("'", """");
                        Write-BCALLog "-->Translations: '$($transUnit.Target -join "';'")'" -logfile $LogFilePath
                        Write-BCALLog "-->Target: $($NewTranslation)" -logfile $LogFilePath
                        try {
                            $currentLine = Sync-BCALCommentPropertyTranslation -PropertyLine $currentLine -LanguageCode $LanguageCode -NewTranslation $NewTranslation -LogFilePath $LogFilePath
                        }
                        catch [Exception] {
                            Write-BCALLog "-->Error with Sync for  '$($currentLineToTranslate)'!" -logfile $LogFilePath
                            Write-BCALLog "-->$($_.Message)" -logfile $LogFilePath
                            throw $_
                        } 
                    
                        Write-BCALLog "-->Old: $($content[$fileLineNo])" -logfile $LogFilePath
                        Write-BCALLog "-->New: $($currentLine)" -logfile $LogFilePath

                        if ($content[$fileLineNo] -ne $currentLine) {
                            $changedPropertyComment++
                            $contentChanged = $true              
                        }   
                        
                        $NewContent.Add($currentLine);

                        #region Multiple translation marker
                        if ($AddTranslationOptions) { 
                            if ($transUnitOptionCount -gt 1) {
                                Write-BCALLog "-->Because there are more translations of this, here are the other found options:" -logfile $LogFilePath
                            
                                $NewContent.Add("// #region Translation Options");
                                $transUnitOptions | ForEach-Object {   
                                    $transUnitOption = $_;
                                    try {
                                        $transUnitOptionLine = Sync-BCALCommentPropertyTranslation -PropertyLine $currentLine -LanguageCode $LanguageCode -NewTranslation $transUnitOption.Target -LogFilePath $LogFilePath                                    
                                        $NewContent.Add("// $($transUnitOptionLine)");
                                    }
                                    catch {
                                        Write-BCALLog "--->Error with Sync in Multiple translation marker for'$($currentLineToTranslate)'!" -logfile $LogFilePath
                                        Write-BCALLog "--->$($_.Message)" -logfile $LogFilePath
                                        throw $_
                                    }
                                }
                                $NewContent.Add("// #endregion Translation Options");
                            }
                        }
                        #endregion Multiple translation marker                        
                    }
                }
            }

            if ($contentChanged) {
                $changedFiles++
                if (!$simulate) {  
                    # TODO: Empty Lines are written...sorry
                    # $NewLine = "`n";
                    # $content += "--"
                    # $content | Select-Object -skiplast 1 | Set-Content $file.FullName -Encoding UTF8
                    # $content[0..($content.Length)] | Out-File $file.FullName -Encoding UTF8

                    Set-Content $file.FullName $NewContent -Encoding UTF8
                }
                else {
                    Write-BCALLog "$($file.Basename) would change but not saved because of simulate switch!" -logfile $LogFilePath
                }
            }
        }
        Write-Progress -Activity $ProgressFileTitle -Completed
        
        $endDate = Get-Date

        If ($simulate) {
            Write-BCALLog "This is only a simulation and not realy change the files!" -logfile $LogFilePath -LogAndWrite
        }

        Write-BCALLog "Changed Files: $($changedFiles)" -logfile $LogFilePath -LogAndWrite
        Write-BCALLog "Changed Property Comments: $($changedPropertyComment)" -logfile $LogFilePath -LogAndWrite
        Write-BCALLog "End: $($endDate)" -logfile $LogFilePath -LogAndWrite
        Write-BCALLog "Duration: $(($endDate - $startDate).Minutes) minutes" -logfile $LogFilePath -LogAndWrite
        Write-BCALLog "Duration Total: $(($endDate - $startDate))" -logfile $LogFilePath -LogAndWrite    
    
        if (![string]::IsNullOrEmpty($LogFilePath)) {
            Write-BCALLog "---------------------------------------------------" -logfile $LogFilePath
        }
    }
}

export-modulemember -function Sync-BCALTransunitTargetsToXliffSyncComment