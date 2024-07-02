<#
.Description
The `Update-BCALAppJson` function updates the `app.json` file and renames the workspace file for a Business Central AL project. It modifies the `app.json` file with new project details and renames the workspace file if a template file exists.
.SYNOPSIS
Updates the app.json file and workspace file name for a Business Central AL project.
.PARAMETER ALProjectDir
The directory of the AL project.
.PARAMETER ProjectName
The name of the project and the name of the workspace file.
.PARAMETER AppName
The name of the app. Defaults to the project name if not specified.
.PARAMETER AppIdRangeStart
The start of the app ID range. Defaults to 50000 if not specified.
.PARAMETER AppIdRangeEnd
The end of the app ID range. Defaults to 90000 if not specified.
.PARAMETER TemplateWorkspaceFileName
The name of the template workspace file. Defaults to "Template" if not specified.
#>
function Update-BCALAppJson {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName)]
        [String] $ALProjectDir,
        [Parameter(Mandatory = $true)]
        [String] $ProjectName,
        [String] $AppName = $ProjectName,
        [String] $AppIdRangeStart = 50000,
        [String] $AppIdRangeEnd = 90000,
        [String]$TemplateWorkspaceFileName = "Template"
    )
    
    begin {}
    
    process {
        $AppAppJsonFilePath = Join-Path $ALProjectDir "App" "app.json"

        #region Update workspacefile name
        $TemplateWorkspaceFile = Join-Path $ALProjectDir "$($TemplateWorkspaceFileName).code-workspace"
        Write-Host "Template Workspace File '$($TemplateWorkspaceFile)' exists: $(Test-Path $TemplateWorkspaceFile)" -ForegroundColor Cyan
        
        if (Test-Path $TemplateWorkspaceFile) {
            $NewWorkspaceFileName = "$($ProjectName).code-workspace"
            Rename-Item -Path $TemplateWorkspaceFile -NewName "$($ProjectName).code-workspace"

            Write-Host "Workspace Renamed: $($NewWorkspaceFileName)"
        }
        #endregion


        #region update app.json
        if (Test-Path $AppAppJsonFilePath) {
            Write-Host "Found App 'app.json': $($AppAppJsonFilePath)" -ForegroundColor Cyan

            $AppJson = Get-Content $AppAppJsonFilePath -Raw | ConvertFrom-Json
            if ($AppName -ne $AppJson.name) {
                Write-Host "Update app.json with Project details..." -ForegroundColor Cyan
                $AppJson.name = $AppName;
                $AppJson.id = (New-Guid).Guid

                $AppJson.idRanges[0].from = [int]$AppIdRangeStart
                $AppJson.idRanges[0].to =  [int]$AppIdRangeEnd

                $AppJson | ConvertTo-Json | Out-File $AppAppJsonFilePath  
                Write-Host "Update app.json done." -ForegroundColor Cyan
            }
        }
        #endregion
    }
    
    end {}
}
Export-ModuleMember -Function Update-BCALAppJson