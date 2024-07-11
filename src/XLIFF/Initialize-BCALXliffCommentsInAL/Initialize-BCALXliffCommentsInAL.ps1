<#
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
.PARAMETER ReplaceDefaultENUFieldToolTipWith
Text to replace the default English field tooltips ("Specifies the value of the (.*?) field.") with the specified language tooltip. Default is the German 'Gibt den Wert des Feldes "$3" an.'.

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
        [string]$ReplaceDefaultENUFieldToolTipWith = 'Gibt den Wert des Feldes "$3" an.'
    )

    begin {}

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
                
                #region Add XLIFF Sync Language Comment
                [string]$TranslatablePropertiesRegEx = "((Caption|ToolTip|InstructionalText)\s*=\s*'([^']+?)');"
                [string]$ReplacementForProperties = "`$1, Comment = '$($LanguageCode)=`$3';"
                $newContent = [regex]::Replace($newContent, $TranslatablePropertiesRegEx, $ReplacementForProperties)
                
                [string]$TranslatableLabelRegEx = "((Label)\s*'([^']+?)');"
                [string]$ReplacementForLabel = "`$1, Comment = '$($LanguageCode)=`$3';"
                $newContent = [regex]::Replace($newContent, $TranslatableLabelRegEx, $ReplacementForLabel)                
                #endregion
                
                #region Replace ENU Default to language Default for Action
                # if 
                if (![string]::IsNullOrEmpty($ReplaceDefaultENUFieldToolTipWith)) {
                    [string]$ChangeDefaultENUTranslationToDefaultLanguageCommentRegEx = "($($LanguageCode)=)(Specifies the value of the (.*?) field.)"
                    [string]$ReplacementForDefaultLanguageComment = "`$1$($ReplaceDefaultENUFieldToolTipWith)"
                    $newContent = [regex]::Replace($newContent, $ChangeDefaultENUTranslationToDefaultLanguageCommentRegEx, $ReplacementForDefaultLanguageComment)
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