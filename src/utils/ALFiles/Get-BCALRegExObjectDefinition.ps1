function Get-BCALRegExObjectDefinition() {
    # multiline, singleline and case insensitive!
    $regex = '(?msi)^(?<Type>\w+)\s(?<ID>\d*)\s"(?<Name>.*?)"(?:\s(extends)\s"(.*)")?'
    Write-Output $regex;
}