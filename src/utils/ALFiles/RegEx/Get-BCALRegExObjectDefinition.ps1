function Get-BCALRegExObjectDefinition() {
    # multiline, singleline and case insensitive!
    $regex = '(?msi)(?:namespace.?(?<Namespace>[\s\S\n]*?);(?:[\s\S\n]*?))?^(?<Type>\w+)\s(?<ID>\d*)\s"(?<Name>.*?)"(?:\s(extends)\s"(.*)")?(?:[\s\S\n]*?{)(?<Content>[\s\S\n]*)(?:[\s\S\n]*?})'
    # Namespace
    # Type
    # ID
    # Name
    # extends
    # Content

    Write-Output $regex;
}