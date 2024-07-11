function Sync-BCALCommentPropertyTranslation {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)]
        [string]$PropertyLine,

        [Parameter(Mandatory = $true)]
        [string]$LanguageCode,

        [Parameter(Mandatory = $true)]
        [string]$NewTranslation,

        [string]$LogFilePath
    )

    Write-BCALLog "-->Check if property already has a comment..." -logfile $LogFilePath
    if ($PropertyLine -match "Comment = '(.*)'") {    
        Write-BCALLog "--->Comment exists. Check if it has the comment in the language code '$($LanguageCode)'" -logfile $LogFilePath
        if ($PropertyLine -match "($LanguageCode=(.*))") {
            Write-BCALLog "---->Replace existing '$($LanguageCode)' comment with new one" -logfile $LogFilePath
            $PropertyLine = $PropertyLine -replace "$LanguageCode=(.*?)(?=[\|';])", "$LanguageCode=$NewTranslation"
        }
        else {
            Write-BCALLog "---->Append new language '$($LanguageCode)' to property" -logfile $LogFilePath
            $PropertyLine = $PropertyLine -replace "';$", "|$LanguageCode=$NewTranslation';"
        }
    }
    else {
        Write-BCALLog "--->No Comment found!" -logfile $LogFilePath

        Write-BCALLog "--->Remove semicolon at the end of property if it exists" -logfile $LogFilePath
        $property = $PropertyLine -replace ';', ''

        Write-BCALLog "--->property $($property)" -logfile $LogFilePath

        Write-BCALLog "--->Append new comment to property" -logfile $LogFilePath
        $PropertyLine = "$property, Comment = '$LanguageCode=$NewTranslation';"
    }

    return $PropertyLine
}