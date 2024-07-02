# Field with Summaries

```PowerShell
(?<CodeSummary>\/\/\/\s\<summary\>(?<SummaryValue>[\s\S\n]*?)\/\/\/\s\<\/summary>(?<SummaryDetails>[\s\S\n]*?))?(?<Field>field\((?<FieldId>[0-9]*);(?<FieldName>.*);(?<FieldDataType>.*)\)[\r\n]+.*(?<FieldContent>(?<PropertyContent>[^}][\s\S\n]*?(?<Property>Description)\s?=\s?'(?<PropertyValue>.*?)?';)?[\s\S\n]*?)})
```

# Analyse Field Property

```PowerShell
(?<CodeSummary>\/\/\/\s\<summary\>(?<SummaryValue>[\s\S\n]*?)\/\/\/\s\<\/summary>(?<SummaryDetails>[\s\S\n]*?))?(?<Field>field\((?<FieldId>[0-9]*);(?<FieldName>.*);(?<FieldDataType>.*)\)[\r\n]+.*(?<FieldContent>(?<PropertyContent>[^}][\s\S\n]*?(?<AnalysePropertyContent>(?<AnalyseProperty>Description)\s?=\s?'(?<AnalysePropertyValue>.*?))?';)?[\s\S\n]*?)})
```


# PropertyLine

```PowerShell
(?<PropertyLine>(?<Property>\w+)(?:\s?=\s?)(?<Value>[\s\S\n]+?);)
```


# "?msi"?

<!-- (?msi) match the remainder of the pattern with the following effective flags: gmsi
m modifier: multi line. Causes ^ and $ to match the begin/end of each line (not only begin/end of string)
s modifier: single line. Dot matches newline characters
i modifier: insensitive. Case insensitive match (ignores case of [a-zA-Z]) -->