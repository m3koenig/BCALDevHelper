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
