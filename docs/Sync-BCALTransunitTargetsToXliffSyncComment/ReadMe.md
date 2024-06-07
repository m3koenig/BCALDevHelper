# Sync-BCALTransunitTargetsToXliffSyncComment

The `Sync-BCALTransunitTargetsToXliffSyncComment` function synchronizes translations from an XLIF file to AL source files by adding or updating comments for the popular [XLIFF Sync](https://marketplace.visualstudio.com/items?itemName=rvanbekkum.xliff-sync). The script scans AL files for properties like `Caption`, `Label`, and `ToolTip`, and inserts the corresponding translations as comments.

## Features

- **Automated Translation Sync**: Finds and inserts translations from an XLIFF file into AL source code comments.
- **Selective Update**: Updates existing comments if they differ from the current translation.
- **Mutliple Languates**: Adds new languages to comments, if not present.

## Usage

Execute `Sync-BCALTransunitTargetsToXliffSyncComment` with the AL Source directory `SrcDirectory` where code comments should be added. Its highly recommended to commit everthing else before that!
Also add the XLF File Path that is used to add the comments to `XLIFFFilePath`.
If there are no translations and you want to use the source as translation, use the parameter `copyFromSource`.

### Example

This Example loads the xlf file, loops thru the AL Files in the source directory, searchs the translatable properties and look in the translationunits for the source of the property.
Also it logs the results and infos into the Logfile.

```PowerShell
    $ALFiles = "C:\Projects\BC\AL\Customer\App\src"
    $XMLFile = "C:\Projects\BC\AL\Customer\App\translations\Customer.de-DE.xlf"
    $LogFile = Join-Path $env:TEMP "Sync-BCALTransunitTargetsToXliffSyncComment.log"
    Sync-BCALTransunitTargetsToXliffSyncComment -SrcDirectory $ALFiles -XLIFFFilePath $XMLFile -LogFilePath $LogFile
```

## How It Works

1. Initialize: Loads necessary utilities and initializes logging.
2. Load Translations: Parses the XLIFF file and loads translations into memory.
3. Scan AL Files: Recursively scans the AL files in the specified directory for translatable properties (Caption, Label, ToolTip, OptionCaption).
4. Update Comments: For each property found, checks if the translation exists in the XLIFF file:
    - If no comment exists, appends the translation as a comment.
    - If a comment exists, replaces it with the new translation if it differs.
5. Log Results: Logs the number of files and properties changed, and details of the operation.

## Notes

Ensure that the AL source files are properly formatted and contain properties that match the patterns used in the script.
Test the script in simulation mode to verify changes before applying them to your source files.
Adjust logging verbosity if needed by modifying the Write-BCALLog calls.

## Troubleshooting

- No Changes Detected: Ensure that the SrcDirectory and XliffFilePath parameters are correctly specified and that the AL files and XLIFF file are accessible.
- Translation Not Applied: Check if the translations are correctly defined in the XLIFF file and match the source text.
- For further customization or issues, review the script logs or contact your development team.
