# Initialize-BCALXliffCommentsInAL

This function will prepare the AL Files for the [XLIFF Sync](https://marketplace.visualstudio.com/items?itemName=rvanbekkum.xliff-sync) VS Code Extension (and PowerShell module). It will add the Comment for a given language code and could also replace the default english field tooltip.
It will not translating anything else. It only adds the comment with the default value of the properties. With the language code you should set your wished language. Sorry to set it to german by default :)

> ⚠️ Please commit everything before you start this.

## Reconized Variables/Properties

- Caption
- ToolTip
- InstructionalText
- Label Variables

## Features
- Adds XLIFF comments to translatable properties and labels.
- Optionally replaces default English field tooltips with a specified language version.
- Logs detailed processing information to a specified log file.


## Notes
- Ensure the AL files are accessible and not locked by other processes during execution.
- Make sure all changes are committed before running this function to avoid conflicts.
- Consider the performance impact if processing large directories.