# Windows Batch Script: searchAssertionsWindows.bat

This is the Windows-compatible version of `searchAssertions.sh` for users running the Find Assertions scripts on Windows systems.

## Overview

`searchAssertionsWindows.bat` provides the same functionality as the bash script but is designed to run natively on Windows Command Prompt or PowerShell. It orchestrates the complete workflow: exports service and policy data, searches for assertions, and exports individual services and policies.

## Prerequisites

### Required Software

1. **Node.js** (v12 or higher)
   - Must be installed and accessible from the command line
   - Verify installation: `node --version`
   - Download from: https://nodejs.org/

2. **Layer7 API Gateway Graphman client**
   - Should be installed at `../../graphman-client-main/` (relative to script location)
   - Or provide the path as an argument
   - **`policyCodeFormat` configuration**: Both `"Code"` and `"json"` values are supported in the `graphman.configuration` options. The scripts detect the format automatically — no configuration change is required:
     - `"Code"` — policy code returned as a parsed object under `policy.code`
     - `"json"` — policy code returned as a JSON string under `policy.json`

3. **`config.json`** (recommended): Create a `config.json` file in the script directory to centralize all parameters. The batch file reads it automatically at startup using `node.exe`:
   ```json
   {
     "graphmanHome": "..\\..\\graphman-client-main",
     "sourceGateway": "aws",
     "targetGateway": "aws",
     "assertionType": "EvaluateJsonPathExpressionV2",
     "exportSchema": "v11.1.3",
     "importSchema": "v11.1.3"
   }
   ```
   - `sourceGateway` / `exportSchema` — used when exporting bundles from the source gateway
   - `targetGateway` / `importSchema` — used when importing bundles into the target gateway
   - Set `sourceGateway` and `targetGateway` to the same value when source and target are the same gateway
   - If `config.json` is absent, built-in defaults are used

4. **Access to the gateway** for exporting services and policies

### Optional Software

- **Git Bash** (recommended for running `.sh` files)
  - If you have Git Bash installed, you can run the original `searchAssertions.sh` script
  - Git Bash allows running bash scripts on Windows
  - Download from: https://git-scm.com/downloads

- **WSL (Windows Subsystem for Linux)** (alternative)
  - Allows running Linux/bash scripts natively on Windows
  - Can use the original `searchAssertions.sh` script

## Usage

### Basic Usage

```cmd
searchAssertionsWindows.bat
```

Uses all default values:
- **Assertion Type**: `EvaluateJsonPathExpressionV2`
- **GRAPHMAN_HOME**: `../../graphman-client-main`
- **Gateway**: `aws`

### With Arguments

```cmd
searchAssertionsWindows.bat [ASSERTION_TYPE] [GRAPHMAN_HOME] [--gateway GATEWAY] [--schema SCHEMA]
```

#### Examples

```cmd
REM Use all defaults from config.json
searchAssertionsWindows.bat

REM Specify assertion type only
searchAssertionsWindows.bat SetVariable

REM Specify assertion type and gateway
searchAssertionsWindows.bat SetVariable --gateway target

REM Specify assertion type, gateway, and export schema
searchAssertionsWindows.bat SetVariable --gateway source --schema v11.1.0

REM Specify all parameters
searchAssertionsWindows.bat EvaluateJsonPathExpressionV2 ..\..\graphman-client-main --gateway aws --schema v11.1.3

REM Different order (flags can be anywhere)
searchAssertionsWindows.bat --schema v11.1.0 --gateway source EvaluateJsonPathExpressionV2
```

### Arguments

- `ASSERTION_TYPE` (optional): The name of the assertion to search for
  - Default: value of `assertionType` in `config.json`, or `EvaluateJsonPathExpressionV2`
  - Examples: `SetVariable`, `HttpRouting`, `DistributedRateLimit`, `EvaluateJsonPathExpressionV2`

- `GRAPHMAN_HOME` (optional): Path to the graphman client directory
  - Default: value of `graphmanHome` in `config.json`, or `..\..\graphman-client-main`
  - Use Windows path format: `..\..\graphman-client-main` or `C:\path\to\graphman-client-main`
  - Can use forward slashes: `../../graphman-client-main` (Windows handles both)

- `--gateway GATEWAY` (optional): Source gateway name to use for exports
  - Default: value of `sourceGateway` in `config.json`, or `aws`
  - Examples: `aws`, `source`, `target`

- `--schema SCHEMA` (optional): Schema version for the graphman export (`--options.schema`)
  - Default: value of `exportSchema` in `config.json`, or `v11.1.3`
  - Examples: `v11.1.0`, `v11.1.3`, `v11.2.1`

## What It Does

1. **Displays configuration**: Shows the configured GRAPHMAN_HOME, Gateway, and Assertion Type

2. **Cleans previous results** (runs automatically via `cleanup.bat`):
   - Stops any running `replaceServer.js` process
   - Removes all files from `generated/` directory
   - Removes `*-results.json` and `*-results.html` files from `response/` directory
   - Preserves the input file `response\spFolderSVCFull.json`

3. **Prompts for assertion replacement and import functionality**:
   - Asks: "Do you want to enable assertion replacement and import functionality? (Yes/No)"
   - The HTML report Replace and Import section displays a **Caution**: the feature is intended for lower environments, with proper quality testing planned for "Replace Assertions" before importing policies/services into the Gateway
   - If you answer **"Yes"**:
     - Enables both "Replace Assertions" and "Import Bundles" buttons in HTML reports
     - Starts `replaceServer.js` automatically in the background
     - The buttons become functional and can be used via the HTML interface
   - If you answer **"No"**:
     - Disables both buttons (grayed out and non-functional) in HTML reports
     - Stops any existing replace server processes
     - You can still manually run `ReplaceAssertions.js` and `ImportBundles.js` from command line

4. **Exports all service and policy data** from the gateway using graphman:
   - Saves to `response\spFolderSVCFull.json`
   - Uses `graphman.bat` (the native Windows graphman executable)

5. **Searches for assertions**:
   - Runs `SearchAssertions.js` with the specified assertion type and replace flag
   - Generates JSON and HTML result files with replace/import functionality enabled/disabled based on your choice
   - HTML reports will show two separate buttons: "Replace Assertions" and "Import Bundles" (enabled or disabled based on your choice)

6. **Exports individual services and policies**:
   - Runs `ExportBundles.js` to export service and policy bundles for items with assertions
   - Saves to `generated\` directory

7. **Optionally starts replace server** (if replacement/import was enabled):
   - Starts `replaceServer.js` in the background to enable HTML-based replacement and import
   - Keeps the server running for use via the HTML interface
   - Replacement is performed via the "Replace Assertions" button in the HTML report
   - Import is performed via the "Import Bundles" button in the HTML report

**Caution (Replace and Import):** The Replace and Import feature is intended for lower environments, where proper quality testing will be planned for "Replace Assertions" before importing the policies/services entities into the Gateway. The HTML report displays this caution in the Replace and Import section.

## Windows-Specific Considerations

### Path Separators

Windows batch files support both forward slashes (`/`) and backslashes (`\`) for paths. The script uses backslashes for Windows compatibility, but forward slashes will also work:

```cmd
REM Both of these work:
searchAssertionsWindows.bat ..\..\graphman-client-main
searchAssertionsWindows.bat ../../graphman-client-main
```

### Running .sh Files

The batch files (`searchAssertionsWindows.bat` and `cleanup.bat`) cover the full Windows workflow natively — no Git Bash or WSL is required. The `.sh` scripts are provided for Mac/Linux users only.

If you still want to run the bash scripts on Windows, options include:

1. **Git Bash** (Recommended):
   - Install Git for Windows which includes Git Bash
   - Allows running `searchAssertions.sh` and `cleanup.sh` natively

2. **WSL (Windows Subsystem for Linux)**:
   - Install from Microsoft Store or via PowerShell
   - Run Linux commands and scripts natively

3. **Cygwin**:
   - Provides a Unix-like environment on Windows

### Process Management

The batch file uses Windows-specific commands for process management:

- **Starting background processes**: Uses `start /B` command
- **Stopping processes**: Uses `taskkill` and `wmic` commands
- **Finding processes**: Uses `tasklist` and `wmic` to find node.exe processes running replaceServer.js

### Stopping the Replace Server

If the replace server is running and you need to stop it:

1. **Using `cleanup.bat`** (Recommended):
   - Run `cleanup.bat` — it automatically finds and kills the running `replaceServer.js` process, and also removes previous result files

2. **Using Task Manager**:
   - Open Task Manager (Ctrl+Shift+Esc)
   - Find `node.exe` process with `replaceServer.js` in the command line
   - End the process

3. **Using Command Line**:
   ```cmd
   wmic process where "commandline like '%replaceServer.js%'" delete
   ```

4. **Using PowerShell**:
   ```powershell
   Get-Process node | Where-Object {$_.CommandLine -like "*replaceServer.js*"} | Stop-Process -Force
   ```

## Differences from Bash Version

| Feature | Bash Scripts | Windows Batch Files |
|---------|-------------|-------------------|
| File extension | `.sh` | `.bat` |
| Shebang / header | `#!/bin/bash` | `@echo off` |
| Variables | `$VAR` | `%VAR%` |
| User input | `read -p` | `set /p` |
| Background process | `&` | `start /B` |
| Process kill | `pkill` | `taskkill` / `wmic` |
| Sleep | `sleep 2` | `timeout /t 2` |
| Path separators | `/` | `\` (both work) |
| Graphman executable | `graphman.sh` | `graphman.bat` (auto-selected by JS scripts) |
| Cleanup script | `cleanup.sh` (bash) | `cleanup.bat` (native Windows) |
| Orchestrator script | `searchAssertions.sh` | `searchAssertionsWindows.bat` |

## Troubleshooting

### Issue: "graphman.bat is not recognized"

**Solution**:
- Verify that `graphman.bat` exists in the `GRAPHMAN_HOME` directory (`%GRAPHMAN_HOME%\graphman.bat`)
- Ensure `GRAPHMAN_HOME` is set correctly — either via `config.json` or as a CLI argument
- Check that Node.js is installed and on the PATH (graphman.bat requires Node.js internally)

### Issue: "Node is not recognized"

**Solution**:
- Install Node.js from https://nodejs.org/
- Ensure Node.js is added to your system PATH
- Restart Command Prompt after installation
- Verify with: `node --version`

### Issue: Replace server won't start

**Solution**:
- Check if port 3001 is already in use: `netstat -ano | findstr :3001`
- Stop any existing node.exe processes running replaceServer.js
- Check Node.js is installed and working: `node --version`
- Try running `replaceServer.js` manually: `node replaceServer.js`

### Issue: Cleanup doesn't remove all expected files

**Solution**:
- `cleanup.bat` is the native Windows cleanup script and runs automatically when `searchAssertionsWindows.bat` is executed
- To run it manually: double-click `cleanup.bat` or run it from Command Prompt: `cleanup.bat`
- It removes all `*.json` files from `generated\` and all `*-results.json` / `*-results.html` files from `response\`
- It preserves `response\spFolderSVCFull.json` (the input file) — this is intentional

### Issue: Path not found errors

**Solution**:
- Use Windows-style paths with backslashes: `..\..\graphman-client-main`
- Or use forward slashes (Windows accepts both): `../../graphman-client-main`
- Use absolute paths if relative paths don't work: `C:\full\path\to\graphman-client-main`
- Ensure paths don't contain spaces, or enclose them in quotes: `"C:\Program Files\graphman"`

### Issue: Buttons are disabled in HTML report

**Solution**:
- Make sure you answered "Yes" when prompted to enable replacement/import
- Check that `replaceServer.js` is running: Open Task Manager and look for node.exe process
- Verify the server is accessible: Open browser and go to `http://localhost:3001/api/health`
- Restart the script and choose "Yes" when prompted

## Integration with Other Scripts

The Windows batch files work with the same Node.js scripts as the bash version:

| Script | Platform | Notes |
|--------|----------|-------|
| `SearchAssertions.js` | All platforms | Node.js script |
| `ExportBundles.js` | All platforms | Node.js script — auto-selects `graphman.bat` on Windows |
| `ImportBundles.js` | All platforms | Node.js script — auto-selects `graphman.bat` on Windows |
| `ReplaceAssertions.js` | All platforms | Node.js script |
| `replaceServer.js` | All platforms | Node.js script |
| `cleanup.bat` | Windows only | Native Windows cleanup script |
| `searchAssertionsWindows.bat` | Windows only | Native Windows orchestrator |
| `cleanup.sh` | Mac/Linux only | Bash script (requires Git Bash/WSL on Windows) |
| `searchAssertions.sh` | Mac/Linux only | Bash script (requires Git Bash/WSL on Windows) |

## Examples

### Complete Workflow Example

```cmd
REM 1. Run the script with custom parameters
searchAssertionsWindows.bat SetVariable ..\..\graphman-client-main --gateway source

REM 2. When prompted, answer "Yes" to enable replacement/import

REM 3. Open the generated HTML report
REM File location: response\setvariable-results.html

REM 4. Use the buttons in the HTML report:
REM    - Click "Replace Assertions" to replace assertions
REM    - Click "Import Bundles" to import bundles

REM 5. When done, stop the replace server using Task Manager or command line
```

### Using with Git Bash

If you have Git Bash installed, you can use the original bash script:

```bash
# In Git Bash
./searchAssertions.sh EvaluateJsonPathExpressionV2 ../../graphman-client-main --gateway aws
```

## Notes

- Both `searchAssertionsWindows.bat` and `cleanup.bat` use `setlocal enabledelayedexpansion` for variable handling in loops
- `cleanup.bat` runs automatically at the start of `searchAssertionsWindows.bat`; it can also be run standalone at any time
- `ExportBundles.js` and `ImportBundles.js` automatically use `graphman.bat` on Windows and `graphman.sh` on Mac/Linux — no manual configuration needed
- All Node.js scripts work the same on Windows as on Linux/Mac
- The replace server runs in the background and persists after the script completes
- Server PID is not easily accessible in batch files, so use Task Manager to stop the server
- Paths with spaces should be enclosed in quotes
- `SearchAssertions.js` supports both Graphman `policyCodeFormat` values (`"Code"` and `"json"`) and detects the format automatically at runtime — no changes to `graphman.configuration` are needed to switch between them
- `config.json` is read by the batch file using `node.exe` to write a temporary `.bat` file with `set` commands, which is then called and deleted. If `node.exe` is not on the PATH before this step the config load is silently skipped and built-in defaults are used
- The `importSchema` in `config.json` is used directly by `ImportBundles.js` and `replaceServer.js` (via the HTML Import Bundles button) — it is not passed through `searchAssertionsWindows.bat` since import is a separate step triggered from the HTML interface

## Support

For issues or questions:
1. Check the main README.md for general documentation
2. Verify all prerequisites are installed
3. Check Windows-specific troubleshooting section above
4. Ensure Node.js and graphman are properly configured

---

**See Also**: [README.md](README.md) for the main documentation covering all scripts and features.
