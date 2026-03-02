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

3. **Access to the gateway** for exporting services and policies

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
searchAssertionsWindows.bat [ASSERTION_TYPE] [GRAPHMAN_HOME] [--gateway GATEWAY]
```

#### Examples

```cmd
REM Use default assertion type but specify gateway
searchAssertionsWindows.bat --gateway source

REM Specify assertion type only
searchAssertionsWindows.bat SetVariable

REM Specify assertion type and gateway
searchAssertionsWindows.bat SetVariable --gateway target

REM Specify all parameters
searchAssertionsWindows.bat EvaluateJsonPathExpressionV2 ..\..\graphman-client-main --gateway aws

REM Different order (gateway flag can be anywhere)
searchAssertionsWindows.bat --gateway source EvaluateJsonPathExpressionV2
```

### Arguments

- `ASSERTION_TYPE` (optional): The name of the assertion to search for
  - Default: `EvaluateJsonPathExpressionV2`
  - Examples: `SetVariable`, `HttpRouting`, `DistributedRateLimit`, `EvaluateJsonPathExpressionV2`

- `GRAPHMAN_HOME` (optional): Path to the graphman client directory
  - Default: `../../graphman-client-main`
  - Use Windows path format: `..\..\graphman-client-main` or `C:\path\to\graphman-client-main`
  - Can use forward slashes: `../../graphman-client-main` (Windows handles both)

- `--gateway GATEWAY` (optional): Gateway name to use
  - Default: `aws`
  - Examples: `aws`, `source`, `target`

## What It Does

1. **Displays configuration**: Shows the configured GRAPHMAN_HOME, Gateway, and Assertion Type

2. **Optionally cleans previous results** (currently disabled by default):
   - Note: The cleanup script (`cleanup.sh`) is a bash script and won't run natively on Windows
   - If you have Git Bash installed, you can uncomment the cleanup lines in the batch file
   - Or manually delete files from `generated/` and `response/` directories

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
   - **Note**: Requires `graphman.sh` to be executable. If it doesn't work, you may need:
     - A Windows version (`graphman.bat` or `graphman.cmd`)
     - Git Bash to run `.sh` files
     - WSL (Windows Subsystem for Linux)

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

If you need to run `.sh` files (like `graphman.sh` or `cleanup.sh`), you have several options:

1. **Git Bash** (Recommended):
   - Install Git for Windows which includes Git Bash
   - Git Bash can execute `.sh` files natively
   - You can then use the original `searchAssertions.sh` script

2. **WSL (Windows Subsystem for Linux)**:
   - Install WSL from Microsoft Store or via PowerShell
   - Run Linux commands and scripts natively
   - You can use the original `searchAssertions.sh` script

3. **Cygwin**:
   - Provides a Unix-like environment on Windows
   - Can run bash scripts

### Process Management

The batch file uses Windows-specific commands for process management:

- **Starting background processes**: Uses `start /B` command
- **Stopping processes**: Uses `taskkill` and `wmic` commands
- **Finding processes**: Uses `tasklist` and `wmic` to find node.exe processes running replaceServer.js

### Stopping the Replace Server

If the replace server is running and you need to stop it:

1. **Using Task Manager**:
   - Open Task Manager (Ctrl+Shift+Esc)
   - Find `node.exe` process with `replaceServer.js` in the command line
   - End the process

2. **Using Command Line**:
   ```cmd
   wmic process where "commandline like '%replaceServer.js%'" delete
   ```

3. **Using PowerShell**:
   ```powershell
   Get-Process node | Where-Object {$_.CommandLine -like "*replaceServer.js*"} | Stop-Process -Force
   ```

## Differences from Bash Version

| Feature | Bash Script | Windows Batch File |
|---------|-------------|-------------------|
| File extension | `.sh` | `.bat` |
| Shebang | `#!/bin/bash` | `@echo off` |
| Variables | `$VAR` | `%VAR%` |
| User input | `read -p` | `set /p` |
| Background process | `&` | `start /B` |
| Process kill | `pkill` | `taskkill` / `wmic` |
| Sleep | `sleep 2` | `timeout /t 2` |
| Path separators | `/` | `\` (both work) |
| Cleanup script | Runs natively | Requires Git Bash/WSL |

## Troubleshooting

### Issue: "graphman.sh is not recognized"

**Solution**: 
- Ensure you have Git Bash installed and the path is correct
- Or create a Windows batch wrapper `graphman.bat` that calls the graphman script
- Or use WSL to run the bash scripts

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

### Issue: Cleanup script doesn't run

**Solution**:
- This is expected - `cleanup.sh` is a bash script
- Install Git Bash to run bash scripts
- Or manually delete files from `generated\` and `response\` directories
- Or uncomment the cleanup lines in the batch file if you have Git Bash installed

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

The Windows batch file works with the same Node.js scripts as the bash version:

- `SearchAssertions.js` - Works on Windows (Node.js script)
- `ExportBundles.js` - Works on Windows (Node.js script)
- `ImportBundles.js` - Works on Windows (Node.js script)
- `ReplaceAssertions.js` - Works on Windows (Node.js script)
- `replaceServer.js` - Works on Windows (Node.js script)
- `cleanup.sh` - Requires Git Bash/WSL (bash script)

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

- The batch file uses `delayed expansion` for variable handling in loops
- All Node.js scripts work the same on Windows as on Linux/Mac
- Only bash-specific scripts (`.sh` files) require special handling
- The replace server runs in the background and persists after the script completes
- Server PID is not easily accessible in batch files, so use Task Manager to stop the server
- Paths with spaces should be enclosed in quotes

## Support

For issues or questions:
1. Check the main README.md for general documentation
2. Verify all prerequisites are installed
3. Check Windows-specific troubleshooting section above
4. Ensure Node.js and graphman are properly configured

---

**See Also**: [README.md](README.md) for the main documentation covering all scripts and features.
