Set-StrictMode -Version 2.0

$verbosePreference = "SilentlyContinue"
$warningPreference = 'Continue'
$errorActionPreference = 'Stop'

$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdministrator = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
try {
    $myUsername = $currentPrincipal.Identity.Name
} catch {
    $myUsername = (whoami)
}

Write-Host ">Hello $($myUsername)!" -ForegroundColor DarkCyan

. (Join-Path $PSScriptRoot ".\src\\utils\Write-BCALLog.ps1")
. (Join-Path $PSScriptRoot ".\src\utils\ALFiles\RegEx\Get-BCALRegExObjectDefinition.ps1")

. (Join-Path $PSScriptRoot ".\src\Get-BCALObjects\Get-BCALObjects.ps1")
. (Join-Path $PSScriptRoot ".\src\Mermaid\New-BCALMermaidClassDiagram\New-BCALMermaidClassDiagram.ps1")
. (Join-Path $PSScriptRoot ".\src\Mermaid\New-BCALMermaidFlowChart\New-BCALMermaidFlowChart.ps1")

. (Join-Path $PSScriptRoot ".\src\CodeSummaries\Update-BCALTableFieldSynopsis\Update-BCALTableFieldSynopsis.ps1")

. (Join-Path $PSScriptRoot ".\src\ToolTips\Add-BCALTableFieldToolTips\Add-BCALTableFieldToolTips.ps1")


. (Join-Path $PSScriptRoot ".\src\XLIFF\Get-BCALXliffAsArray\Get-BCALXliffAsArray.ps1")
. (Join-Path $PSScriptRoot ".\src\XLIFF\Sync-BCALTransunitTargetsToXliffSyncComment\Sync-BCALTransunitTargetsToXliffSyncComment.ps1")
. (Join-Path $PSScriptRoot ".\src\XLIFF\Initialize-BCALXliffCommentsInAL/Initialize-BCALXliffCommentsInAL.ps1")

. (Join-Path $PSScriptRoot ".\src\Update-BCALAppJson\Update-BCALAppJson.ps1")