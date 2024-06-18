function Get-BCALRegExObjectDefinition() {
    $regex = '(?<Type>\w+)\s(?<ID>\d*)\s"(?<Name>.*?)"(?:\s(extends)\s"(.*)")?'
    Write-Output $regex;
}