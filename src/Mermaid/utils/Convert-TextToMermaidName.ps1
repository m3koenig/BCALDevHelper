function Convert-TextToMermaidName {
    [CmdletBinding()]
    [OutputType([int])]
    Param(
        $InputText
    )

    process {
        $ConvertedText = $InputText
        $ConvertedText = $ConvertedText.Replace('.', '');
        $ConvertedText = $ConvertedText.Replace(' ', '_');
        $ConvertedText = $ConvertedText.Replace('-', '_');
        $ConvertedText = $ConvertedText.Replace('"', '');
        $ConvertedText = $ConvertedText.Replace('/', '_');
        $ConvertedText = $ConvertedText.Replace('(', '_');
        $ConvertedText = $ConvertedText.Replace(')', '_');
        $ConvertedText = $ConvertedText.Replace('=', '_');
        $ConvertedText = $ConvertedText.Replace('&', '_');

        return $ConvertedText
    }
}