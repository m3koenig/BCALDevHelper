﻿<#
.SYNOPSIS
Processes AL files to insert XLIFF comments for specific properties and labels and could updates default English action tooltips to a specified language.
.DESCRIPTION
This function scans AL files within a specified directory, identifies translatable properties and labels, and adds XLIFF comments based on a given language code. It also could updates default English field tooltips ("Specifies the value of the (.*?) field.") to a specified language tooltip. The function logs detailed information about its processing steps.
.PARAMETER SourceFilePath
Specifies the root path where the AL files are located. This parameter is mandatory.
.PARAMETER LogFilePath
Specifies the file path for logging verbose messages of this module.
.PARAMETER LanguageCode
The language code to use in the XLIFF comments. Default is 'de-DE'.
.PARAMETER OverwriteLanguageComment
Will overwrite the current XLIFF Language Comment with the Source.
.PARAMETER ReplaceDefaultENUFieldToolTipWith
Text to replace the default English field tooltips ("Specifies the value of the (.*?) field.") with the specified language tooltip. Default is the German 'Gibt den Wert des Feldes "$3" an.'.
.PARAMETER ReplaceDefaultENUActionToolTipWith
Text to replace the default English action tooltips ("Executes the (.*?) action.") with the specified language tooltip. Default is the German 'Gibt den Wert des Feldes "$3" an.'.

.EXAMPLE
# This example processes AL files in the `C:\Projects\ALFiles` directory, logs messages to `C:\Logs\BCALLog.txt`, uses French for XLIFF comments, and replaces the default English tooltip with a French version.
Initialize-BCALXliffCommentsInAL -SourceFilePath "C:\Projects\ALFiles" -LogFilePath "C:\Logs\BCALLog.txt" -LanguageCode "fr-FR" -ReplaceDefaultENUFieldToolTipWith "Spécifie la valeur du champ « $3 »."

.EXAMPLE
# This example processes AL files in the `C:\ALFiles` directory, uses the default German language code 'de-DE', and not replace the default English field tooltips.
Initialize-BCALXliffCommentsInAL -SourceFilePath "C:\ALFiles"

.NOTES
Ensure the AL files are accessible and not locked by other processes during execution. Also that everything is commited before you execute this function.
If processing large directories, consider the performance impact.
#>
# TODO: Report Labels?
function Initialize-BCALXliffCommentsInAL {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourceFilePath,

        [string]$LogFilePath,
        [string]$LanguageCode = 'de-DE',
        [switch]$OverwriteLanguageComment,
        [string]$ReplaceDefaultENUFieldToolTipWith = 'Gibt den Wert des Feldes "$3" an.',
        [string]$ReplaceDefaultENUActionToolTipWith = 'Führt die Aktion "$3" aus.'
    )

    begin {
        Write-BCALLog -Level VERBOSE "To use this function, its neccasary to have the default Captions, Tooltips etc. in the file (use AZ AL DevTools Extension). Then it will add the XLIFF Comments!" -logfile $LogFilePath
        Write-BCALLog -Level VERBOSE "It will also overwrite the current Comment! Please commit before and check the new values before you publish them!" -logfile $LogFilePath
        Write-BCALLog -Level VERBOSE "---" -logfile $LogFilePath
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
                # Get Content
                [string]$FileContent = Get-Content -Path $CurrFile.FullName -Raw
                if (![string]::IsNullOrEmpty($FileContent)) {
                    Write-BCALLog -Level VERBOSE "Object found: '$($CurrFile.FullName)'" -logfile $LogFilePath
                }

                # Perform the regex replacement
                $newContent = $FileContent
                
                [string]$TranslatablePropertiesRegEx = "(?i)((Caption|ToolTip|InstructionalText)\s*=\s*'([^']+?)')";

                if ($OverwriteLanguageComment) {
                    #region Update XLIFF Sync Language Comment for properties
                    Write-BCALLog -Level VERBOSE "Update XLIFF Sync Language Comment..." -logfile $LogFilePath
                    [string]$TranslatablePropertiesWithCommentsRegEx = "$($TranslatablePropertiesRegEx)(?:, Comment\s*=\s*([\s\S\n]*?));"
                    [string]$ReplacementForPropertyWithComment = "`$1, Comment = '$($LanguageCode)=`$3';"
                    $newContent = [regex]::Replace($newContent, $TranslatablePropertiesWithCommentsRegEx, $ReplacementForPropertyWithComment)
                    #endregion
                }
                
                #region Add XLIFF Sync Language Comment for properties
                Write-BCALLog -Level VERBOSE "Add XLIFF Sync Language Comment for translateable properties..." -logfile $LogFilePath
                [string]$TranslatablePropertiesEndOfPropertyRegEx = "$($TranslatablePropertiesRegEx);"
                [string]$ReplacementForProperty = "`$1, Comment = '$($LanguageCode)=`$3';"
                $newContent = [regex]::Replace($newContent, $TranslatablePropertiesEndOfPropertyRegEx, $ReplacementForProperty)                
                #endregion
                
                #region Add XLIFF Sync Language Comment for Labels
                Write-BCALLog -Level VERBOSE "Add XLIFF Sync Language Comment for Labels..." -logfile $LogFilePath
                [string]$TranslatableLabelRegEx = "((Label)\s*'([^']+?)');"
                [string]$ReplacementForLabel = "`$1, Comment = '$($LanguageCode)=`$3';"
                $newContent = [regex]::Replace($newContent, $TranslatableLabelRegEx, $ReplacementForLabel)                
                #endregion
                
                #region Replace ENU Default to language Default for Tooltips
                Write-BCALLog -Level VERBOSE "Replace ENU Default to language Default for Field Tooltips..." -logfile $LogFilePath
                if (![string]::IsNullOrEmpty($ReplaceDefaultENUFieldToolTipWith)) {
                    [string]$ChangeDefaultENUTranslationForFieldToDefaultLanguageCommentRegEx = "($($LanguageCode)=)(Specifies the value of the (.*?) field.)"
                    [string]$ReplacementForDefaultLanguageCommentForField = "`$1$($ReplaceDefaultENUFieldToolTipWith)"
                    $newContent = [regex]::Replace($newContent, $ChangeDefaultENUTranslationForFieldToDefaultLanguageCommentRegEx, $ReplacementForDefaultLanguageCommentForField)
                }
                #endregion

                #region Replace ENU Default to language Default for Action
                Write-BCALLog -Level VERBOSE "Replace ENU Default to language Default for Action..." -logfile $LogFilePath
                if (![string]::IsNullOrEmpty($ReplaceDefaultENUActionToolTipWith)) {
                    [string]$ChangeDefaultENUTranslationForActionToDefaultLanguageCommentRegEx = "($($LanguageCode)=)(Executes the (.*?) action.)"
                    [string]$ReplacementForDefaultLanguageCommentForAction = "`$1$($ReplaceDefaultENUActionToolTipWith)"
                    $newContent = [regex]::Replace($newContent, $ChangeDefaultENUTranslationForActionToDefaultLanguageCommentRegEx, $ReplacementForDefaultLanguageCommentForAction)
                }
                #endregion

                # Write the modified content back to the file
                # Set-Content -Path $CurrFile.FullName -Value $newContent
                $newContent | Out-File -FilePath $CurrFile.FullName -NoNewline -Force 
            }
        }

    }

    end {}    
}
Export-ModuleMember -Function Initialize-BCALXliffCommentsInAL