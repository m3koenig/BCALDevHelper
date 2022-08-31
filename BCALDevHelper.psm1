#Requires -PSEdition Desktop 

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

Write-Host "Hello $($myUsername)!"

. (Join-Path $PSScriptRoot ".\Get-BCALObjects\Get-BCALObjects.ps1")
. (Join-Path $PSScriptRoot ".\Mermaid\New-BCALMermaidClassDiagram\New-BCALMermaidClassDiagram.ps1")
. (Join-Path $PSScriptRoot ".\Mermaid\New-BCALMermaidFlowChart\New-BCALMermaidFlowChart.ps1")