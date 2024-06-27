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

. (Join-Path $PSScriptRoot ".\utils\Write-BCALLog.ps1")
. (Join-Path $PSScriptRoot ".\utils\ALFiles\Get-BCALRegExObjectDefinition.ps1")

. (Join-Path $PSScriptRoot ".\Get-BCALObjects\Get-BCALObjects.ps1")
. (Join-Path $PSScriptRoot ".\Mermaid\New-BCALMermaidClassDiagram\New-BCALMermaidClassDiagram.ps1")
. (Join-Path $PSScriptRoot ".\Mermaid\New-BCALMermaidFlowChart\New-BCALMermaidFlowChart.ps1")

. (Join-Path $PSScriptRoot ".\CodeSummaries\Initialize-BCALTableFieldCodeSummaries\Initialize-BCALTableFieldCodeSummaries.ps1")

. (Join-Path $PSScriptRoot ".\ToolTips\Add-BCALTableFieldToolTips\Add-BCALTableFieldToolTips.ps1")


. (Join-Path $PSScriptRoot ".\XLIFF\Get-BCALXliffAsArray\Get-BCALXliffAsArray.ps1")
. (Join-Path $PSScriptRoot ".\XLIFF\Sync-BCALTransunitTargetsToXliffSyncComment\Sync-BCALTransunitTargetsToXliffSyncComment.ps1")
. (Join-Path $PSScriptRoot ".\XLIFF\Initialize-BCALXliffCommentsInAL/Initialize-BCALXliffCommentsInAL.ps1")

. (Join-Path $PSScriptRoot ".\Update-BCALAppJson\Update-BCALAppJson.ps1")