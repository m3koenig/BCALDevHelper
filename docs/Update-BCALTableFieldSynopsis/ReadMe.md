# Update-BCALTableFieldSynopsis

The `Update-BCALTableFieldSynopsis` function processes AL files within a specified directory to ensure each table or table extension field has a properly formatted summary comment. The function scans the files, identifies tables or table extensions, and updates or creates summary comments with metadata, including:

- Field caption
- Description
- Field class

Additionally, it adds a synopsis under the summary in the following format:

```
<Caption> / <Caption Comment> / <Description: DescriptionValue> / <Field Class if not normal>
```

The updated content is saved back to the original files.

## Parameters

### SourceFilePath

- **Type:** String
- **Description:** The path to the directory containing AL files to process. It can also be a single file.
- **Mandatory:** Yes

### LogFilePath

- **Type:** String
- **Description:** The path to the log file for verbose logging.
- **Mandatory:** No

## Examples

### Example 1

```powershell
Update-BCALTableFieldSynopsis -SourceFilePath "C:\Source\BCALFiles"
```

Updates the field summaries in all AL files in the specified directory without logging.

### Example 2

```powershell
Update-BCALTableFieldSynopsis -SourceFilePath "C:\Source\BCALFiles" -LogFilePath "C:\Logs\BCALUpdate.log"
```

Updates the field summaries and logs detailed processing information to the specified log file.
