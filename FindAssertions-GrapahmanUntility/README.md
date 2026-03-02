# Find Assertions Scripts

This directory contains scripts for searching and exporting services based on assertion types in Layer7 API Gateway policies.

## Overview

The scripts help you:
1. **Search for specific assertions** in service and policy bundles across multiple services and policies
2. **Generate HTML and JSON reports** showing which services and policies contain the specified assertions
3. **Export individual service and policy bundles** for items that contain the assertions
4. **Replace assertions** in exported bundle files and prepare them for import back to the gateway

## Prerequisites

- Node.js (v12 or higher)
- Layer7 API Gateway Graphman client installed at `../../graphman-client-main/`
- Access to the gateway for exporting services and policies
- JSON file containing service and/or policy data at `response/spFolderSVCFull.json` (can contain both `services` and `policies` arrays)
- **Graphman Configuration**: The `graphman.configuration` file must have `PolicyCodeFormat` set to `"Code"` in the `options` section:
  ```json
  {
    "options": {
      "policyCodeFormat": "Code",
      ...
    }
  }
  ```
  This ensures that policy code is exported in the correct format for the scripts to parse and search through.

## Scripts

### 1. SearchAssertions.js

Searches through service and policy bundles to find services and policies containing a specific assertion type.

#### Usage

```bash
node SearchAssertions.js [assertionType]
```

#### Arguments

- `assertionType` (optional): The name of the assertion to search for
  - Default: `EvaluateJsonPathExpressionV2`
  - Examples: `SetVariable`, `HttpRouting`, `DistributedRateLimit`, `EvaluateJsonPathExpressionV2`

#### What it does

1. Reads service and policy data from `response/spFolderSVCFull.json` (supports both `services` and `policies` arrays)
2. Searches for the specified assertion in both services and policies:
   - **Services**: Searches in `service.policy.code.All` (direct level) and `service.policy.code.All.OneOrMore.All` (nested level)
   - **Policies**: Searches in `policy.policy.code.All` (direct level) and `policy.policy.code.All.OneOrMore.All` (nested level)
3. Generates two output files:
   - **JSON file**: `response/<assertion-name>-results.json` - Contains detailed results for both services and policies
   - **HTML file**: `response/<assertion-name>-results.html` - Visual report with table showing services and policies

#### Output Files

**JSON Output** (`response/<assertion-name>-results.json`):
```json
{
  "timestamp": "2026-01-15T19:26:18.722Z",
  "inputFile": "...",
  "hostname": "localhost",
  "searchAssertion": "EvaluateJsonPathExpressionV2",
  "totalServices": 9,
  "totalPolicies": 5,
  "totalItems": 14,
  "itemsWithAssertion": 3,
  "results": [
    {
      "type": "Service",
      "name": "TEST01",
      "resolutionPath": "/rest/test01",
      "folderPath": "/SpecialFolder",
      "exists": true,
      "policyDetails": { ... }
    },
    {
      "type": "Policy",
      "name": "MyPolicy",
      "resolutionPath": "N/A",
      "folderPath": "/Policies",
      "exists": true,
      "policyDetails": { ... }
    }
  ]
}
```

**HTML Output** (`response/<assertion-name>-results.html`):
- Professional grey-themed report
- Table showing all services and policies with:
  - **Serial No** - Sequential row number
  - **Type** - Item type (Service or Policy)
  - **Name** - Service or policy name (clickable links for items with assertions)
  - **Resolution Path** - Service resolution path (N/A for policies)
  - **Folder Path** - Service or policy folder path in gateway
  - **Assertions Exists** (Yes/No)
- Color-coded rows (blue for Yes, yellow for No)
- Gateway hostname information
- Statistics summary showing total items, services, policies, and items with assertions
- **Replace and Import functionality**: Interactive form with two separate buttons (enabled/disabled based on user choice)
  - **Caution label**: The Replace and Import section displays a caution stating that this feature is intended for lower environments, where proper quality testing will be planned for "Replace Assertions" before importing the policies/services entities into the Gateway
  - Text field for entering the replacement assertion name
  - **"Replace Assertions" button** (purple): Triggers assertion replacement in bundle files via `ReplaceAssertions.js`
  - **"Import Bundles" button** (green): Triggers import of all bundles from `generated/` directory via `ImportBundles.js`
  - Both buttons can be enabled or disabled based on user interaction when running `searchAssertions.sh`
  - When enabled: Both buttons are functional and require `replaceServer.js` to be running
  - When disabled: Both buttons are grayed out and non-functional

#### Examples

```bash
# Search for EvaluateJsonPathExpressionV2 (default)
node SearchAssertions.js

# Search for SetVariable assertion
node SearchAssertions.js SetVariable

# Search for DistributedRateLimit assertion
node SearchAssertions.js DistributedRateLimit

# Search for HttpRouting assertion
node SearchAssertions.js HttpRouting
```

#### Features

- **Dual search capability**: Searches both services and policies in the Graphman bundle
- **Case-insensitive search**: Handles various case combinations (All/all, OneOrMore/oneOrMore)
- **Nested search**: Finds assertions in both direct and nested policy structures
- **Comprehensive reporting**: Includes all services and policies (both with and without the assertion)
- **Type identification**: Results clearly distinguish between Services and Policies
- **Interactive HTML**: Clickable service and policy names link to exported bundle files (when available)
- **Flexible input**: Works with bundles containing only services, only policies, or both
- **Split button functionality**: Two separate buttons for replace and import operations
  - **"Replace Assertions" button**: Handles assertion replacement in bundle files
  - **"Import Bundles" button**: Handles importing bundles to the gateway
  - Both buttons can be enabled/disabled based on user choice when running `searchAssertions.sh`

---

### 2. ExportBundles.js

Exports individual service and policy bundles for services and policies that contain the specified assertions.

#### Usage

```bash
node ExportBundles.js [GRAPHMAN_HOME] [--gateway GATEWAY]
```

#### Arguments

- `GRAPHMAN_HOME` (optional): Path to the graphman client directory
  - Default: `../../graphman-client-main`
  - Example: `/path/to/graphman-client-main` or `../../graphman-client-main`
- `--gateway GATEWAY` (optional): Gateway name to use for exports
  - Default: `aws`
  - Examples: `aws`, `source`, `target`

#### What it does

1. Scans `response/` directory for all `*-results.json` files
2. Filters items where `exists: true` (services and policies that contain the assertion)
3. Separates items by type (Service or Policy)
4. For each **Service**:
   - Looks up the service's `resolutionPath` from the original service data
   - Exports the individual service using graphman
   - Saves to `generated/<service-name>.json`
5. For each **Policy**:
   - Exports the individual policy using graphman with dependencies
   - Saves to `generated/<policy-name>.json`

#### Export Commands

The script uses different graphman command formats based on item type:

**For Services**:
```bash
graphman.sh export --gateway aws --using service --variables.resolutionPath <resolutionPath> --output generated/<service-name>.json
```

**For Policies**:
```bash
graphman.sh export --gateway aws --using policy --variables.name <policyName> --variables.includeAllDependencies --output generated/<policy-name>.json
```

#### Output

- **Location**: `generated/` directory
- **Format**: Individual JSON files, one per service or policy
- **Naming**: `<sanitized-name>.json` (special characters replaced with underscores)
- **Types**: Both service bundles and policy bundles are exported

#### Examples

```bash
# Export all services and policies with assertions found in results files (use defaults)
node ExportBundles.js

# Specify only GRAPHMAN_HOME
node ExportBundles.js /path/to/graphman-client-main

# Specify only gateway
node ExportBundles.js --gateway source

# Specify both GRAPHMAN_HOME and gateway
node ExportBundles.js ../../graphman-client-main --gateway aws

# Different order (gateway flag can be anywhere)
node ExportBundles.js --gateway source ../../graphman-client-main
```

#### Features

- **Dual export capability**: Exports both services and policies that contain the specified assertions
- **Type-aware export**: Uses appropriate graphman command based on item type (Service or Policy)
- **Selective export**: Only exports items where assertions were found (`exists: true`)
- **Individual files**: Each service or policy gets its own export file (not folder-based)
- **Policy dependencies**: Policies are exported with `--variables.includeAllDependencies` to include all related dependencies
- **Automatic file naming**: Sanitizes names for valid filenames
- **Error handling**: Verifies file creation and provides detailed error messages
- **Comprehensive summary**: Shows separate counts for services and policies, with overall totals

#### Output Example

```
Starting service and policy export process...

Found 1 results file(s)

Found 3 unique service(s) to export
Found 2 unique policy/policies to export

Exporting service: TEST01 (/rest/test01)...
  Output: /path/to/generated/TEST01.json
✓ Successfully exported: TEST01 (12345 bytes)

Exporting policy: MyPolicy...
  Output: /path/to/generated/MyPolicy.json
✓ Successfully exported: MyPolicy (8765 bytes)

...

==================================================
Export Summary:
  Total items: 5
    Services: 3 (Successful: 3, Failed: 0)
    Policies: 2 (Successful: 2, Failed: 0)
  Overall: Successful: 5, Failed: 0
  Output directory: /path/to/generated
==================================================
```

---

### 3. ReplaceAssertions.js

Replaces assertions in exported bundle files based on previous search results. This script reads the search results JSON file and updates the corresponding bundle files in the `generated/` directory.

> **⚠ CAUTION:** Replacement and Import feature is intended for lower environments, where proper quality testing will be planned for "Replace Assertions" before importing the policies/services entities into the Gateway.

#### Usage

```bash
node ReplaceAssertions.js <results-file> <searchAssertion> <replaceAssertion>
```

#### Arguments

- `results-file` (required): Path to the search results JSON file (e.g., `response/evaluatejsonpathexpressionv2-results.json`)
- `searchAssertion` (required): The assertion name to find and replace (e.g., `EvaluateJsonPathExpressionV2`)
- `replaceAssertion` (required): The assertion name to replace with (e.g., `EvaluateJsonPathExpressionV3`)

#### What it does

1. Reads the search results JSON file from a previous `SearchAssertions.js` run
2. Filters items where `exists: true` (both Services and Policies)
3. For each item that needs replacement:
   - Locates the corresponding bundle file in `generated/` directory (e.g., `generated/TEST01.json`)
   - Creates a timestamped backup of the bundle file
   - Replaces the assertion in the bundle file's policy structure
   - Updates the bundle file with the new assertion name
4. Provides a detailed summary of replacements

#### How it works

- **Uses search results**: Instead of re-searching, it leverages the existing search results to know exactly which items need replacement
- **Updates bundle files**: Modifies the individual bundle files in `generated/` directory (not the source `spFolderSVCFull.json`)
- **Creates backups**: Each bundle file gets a timestamped backup before modification
- **Handles both types**: Works with both Service bundles and Policy bundles

#### Examples

```bash
# Replace EvaluateJsonPathExpressionV2 with EvaluateJsonPathExpressionV3
node ReplaceAssertions.js response/evaluatejsonpathexpressionv2-results.json EvaluateJsonPathExpressionV2 EvaluateJsonPathExpressionV3

# Replace HttpRouting with HttpRoutingV2
node ReplaceAssertions.js response/httprouting-results.json HttpRouting HttpRoutingV2
```

#### Output

The script provides detailed console output showing:
- Items found to process (separated by Services and Policies)
- Replacement progress for each item
- Summary with total replacements by type
- Location of updated files and backups

#### Features

- **No duplicate search**: Uses existing search results instead of re-searching
- **Selective replacement**: Only processes items where `exists: true` from search results
- **Automatic backups**: Creates timestamped backups for each bundle file
- **Type-aware**: Handles both Service and Policy bundle structures correctly
- **Safe operation**: Verifies files exist before processing
- **Detailed reporting**: Shows exactly what was replaced and what failed

#### Prerequisites

- **Must have run `SearchAssertions.js` first** to generate the results file
- **Must have run `ExportBundles.js`** to generate the bundle files in `generated/` directory
- **Must have `replaceServer.js` running** (if using HTML interface) - this is a prerequisite for HTML-based replacement
- Bundle files must exist in `generated/` directory for items to be replaced

**Note**: When using the HTML interface, `replaceServer.js` must be running as a prerequisite. This is typically started automatically by `searchAssertions.sh` when you choose "Yes" to enable replacement. If running manually, start the server before using the HTML "Replace Assertions" button.

---

### 4. ImportBundles.js

Imports all bundle files from the `generated/` directory into the specified gateway. This script is the counterpart to `ExportBundles.js` and allows you to import all exported service and policy bundles back to the gateway.

> **⚠ CAUTION:** Replacement and Import feature is intended for lower environments, where proper quality testing will be planned for "Replace Assertions" before importing the policies/services entities into the Gateway.

#### Usage

```bash
node ImportBundles.js [GRAPHMAN_HOME] [--gateway GATEWAY]
```

#### Arguments

- `GRAPHMAN_HOME` (optional): Path to the graphman client directory
  - Default: `../../graphman-client-main`
  - Example: `/path/to/graphman-client-main` or `../../graphman-client-main`
- `--gateway GATEWAY` (optional): Gateway name to use for imports
  - Default: `aws`
  - Examples: `aws`, `source`, `target`

#### What it does

1. Scans `generated/` directory for all `*.json` files
2. Excludes backup files (files with `.backup.` in the name)
3. For each bundle file:
   - Imports the bundle using graphman import command
   - Uses the specified gateway for import
   - Provides detailed output for each import operation

#### Import Command

The script uses the following graphman command format for each bundle:

```bash
graphman.sh import --gateway <gateway> --input <absolute-path-to-bundle-file>
```

#### Input Files

- **Location**: `generated/` directory
- **Format**: JSON bundle files (service or policy bundles)
- **Exclusions**: Backup files (`.backup.*.json`) are automatically excluded
- **Types**: Both service bundles and policy bundles are imported

#### Examples

```bash
# Import all bundles from generated/ directory (use defaults)
node ImportBundles.js

# Specify only GRAPHMAN_HOME
node ImportBundles.js /path/to/graphman-client-main

# Specify only gateway
node ImportBundles.js --gateway source

# Specify both GRAPHMAN_HOME and gateway
node ImportBundles.js ../../graphman-client-main --gateway aws

# Different order (gateway flag can be anywhere)
node ImportBundles.js --gateway source ../../graphman-client-main
```

#### Features

- **Automatic file discovery**: Scans and imports all bundle files in `generated/` directory
- **Backup exclusion**: Automatically skips backup files created by `ReplaceAssertions.js`
- **Type-agnostic**: Works with both service and policy bundles
- **Error handling**: Provides detailed error messages for failed imports
- **Comprehensive summary**: Shows total files, successful imports, and failures
- **Gateway flexibility**: Supports different gateways via command-line parameter

#### Output Example

```
Starting bundle import process...
  GRAPHMAN_HOME: ../../graphman-client-main
  Gateway: aws
  Graphman path: ../../graphman-client-main/graphman.sh

Found 5 bundle file(s) to import

Importing bundle: TEST01.json...
  Input: /path/to/generated/TEST01.json
  Command: ../../graphman-client-main/graphman.sh import --gateway aws --input "/path/to/generated/TEST01.json"
  Graphman output:
  Import completed successfully
✓ Successfully imported: TEST01.json

Importing bundle: MyPolicy.json...
  Input: /path/to/generated/MyPolicy.json
  Command: ../../graphman-client-main/graphman.sh import --gateway aws --input "/path/to/generated/MyPolicy.json"
  Graphman output:
  Import completed successfully
✓ Successfully imported: MyPolicy.json

...

==================================================
Import Summary:
  Total files: 5
  Successful: 5
  Failed: 0
  Input directory: /path/to/generated
==================================================
```

#### Prerequisites

- **Must have bundle files**: Run `ExportBundles.js` first to generate bundle files in `generated/` directory
- **Gateway access**: Must have connectivity and permissions to import to the specified gateway
- **Valid bundles**: Bundle files must be valid JSON and contain properly formatted service or policy data

#### Notes

- The script imports all `.json` files in `generated/` directory except backup files
- Backup files (created by `ReplaceAssertions.js`) are automatically excluded
- Each bundle is imported individually, so you can see the status of each import
- Failed imports are reported but don't stop the process for other files
- Use this script after modifying bundles with `ReplaceAssertions.js` to import the updated bundles back to the gateway

---

### 5. searchAssertions.sh

Bash script that orchestrates the complete workflow: exports service and policy data, searches for assertions, and exports individual services and policies.

#### Usage

```bash
./searchAssertions.sh [ASSERTION_TYPE] [GRAPHMAN_HOME] [--gateway GATEWAY]
```

#### Arguments

- `ASSERTION_TYPE` (optional): The name of the assertion to search for
  - Default: `EvaluateJsonPathExpressionV2`
  - Examples: `SetVariable`, `HttpRouting`, `DistributedRateLimit`
- `GRAPHMAN_HOME` (optional): Path to the graphman client directory
  - Default: `../../graphman-client-main`
- `--gateway GATEWAY` (optional): Gateway name to use
  - Default: `aws`
  - Examples: `aws`, `source`, `target`

#### What it does

1. **Optionally cleans previous results** (if enabled - currently disabled by default):
   - Runs `cleanup.sh` to remove previous result files and generated exports
   - Preserves input data file (`spFolderSVCFull.json`)

2. **Prompts for assertion replacement and import functionality**:
   - Asks: "Do you want to enable assertion replacement and import functionality? (Yes/No)"
   - If you answer **"Yes"**:
     - Enables both "Replace Assertions" and "Import Bundles" buttons in HTML reports
     - Starts `replaceServer.js` automatically in the background
     - The buttons become functional and can be used via the HTML interface
   - If you answer **"No"**:
     - Disables both buttons (grayed out and non-functional) in HTML reports
     - Ensures no replace server is running (stops any existing instance)
     - You can still manually run `ReplaceAssertions.js` and `ImportBundles.js` from command line if needed

3. **Exports all service and policy data** from the gateway using graphman:
   - Saves to `response/spFolderSVCFull.json`

4. **Searches for assertions**:
   - Runs `SearchAssertions.js` with the specified assertion type and replace flag
   - Generates JSON and HTML result files with replace/import functionality enabled/disabled based on user choice
   - HTML reports will show two separate buttons: "Replace Assertions" and "Import Bundles" (enabled or disabled based on your choice)

5. **Exports individual services and policies**:
   - Runs `ExportBundles.js` to export service and policy bundles for items with assertions
   - Saves to `generated/` directory

6. **Optionally starts replace server** (if replacement/import was enabled):
   - Starts `replaceServer.js` in the background to enable HTML-based replacement and import
   - Keeps the server running for use via the HTML interface
   - Replacement is performed via the "Replace Assertions" button in the HTML report
   - Import is performed via the "Import Bundles" button in the HTML report

#### Examples

```bash
# Use all defaults
./searchAssertions.sh

# Specify only assertion type
./searchAssertions.sh SetVariable

# Specify assertion type and gateway
./searchAssertions.sh SetVariable --gateway source

# Specify all parameters
./searchAssertions.sh EvaluateJsonPathExpressionV2 ../../graphman-client-main --gateway aws

# Different order (gateway flag can be anywhere)
./searchAssertions.sh --gateway source SetVariable
```

#### Features

- **Complete workflow**: Automates the entire process from data export to service export
- **Interactive replacement**: Prompts user to enable/disable assertion replacement functionality
- **Automatic server management**: Starts/stops replace server based on user choice
- **HTML-based replacement**: Replacement is performed via the HTML interface, not command line
- **Optional cleanup**: Can be configured to clean previous results before running (disabled by default)
- **Parameter passing**: Passes all parameters to the underlying scripts
- **Error handling**: Exits with error if any step fails
- **Information display**: Shows configured values at startup
- **Server persistence**: Keeps replace server running for HTML interface use

#### Replacement and Import Integration

The script includes interactive assertion replacement and import functionality. The HTML report displays a **Caution** in the Replace and Import section: *Replacement and Import feature is intended for lower environments, where proper quality testing will be planned for "Replace Assertions" before importing the policies/services entities into the Gateway.*

**When you choose "Yes" to enable replacement/import:**
- Both "Replace Assertions" and "Import Bundles" buttons in HTML reports will be enabled
- `replaceServer.js` will be started automatically in the background
- Replacement is performed via the "Replace Assertions" button in the HTML report
- Import is performed via the "Import Bundles" button in the HTML report
- The server remains running for use via the HTML interface

**When you choose "No" to disable replacement/import:**
- Both "Replace Assertions" and "Import Bundles" buttons in HTML reports will be disabled (grayed out)
- Any existing replace server will be stopped
- You can still manually run `ReplaceAssertions.js` and `ImportBundles.js` from command line if needed

**Server Management:**
- The replace server runs in the background and persists after the script completes
- Server PID is displayed so you can stop it manually if needed: `kill <PID>`
- The server must be running to use the HTML "Replace Assertions" and "Import Bundles" buttons
- The server provides two API endpoints:
  - `/api/replace-and-import` - For assertion replacement
  - `/api/import-bundles` - For bundle import

#### Cleanup Integration

The script includes optional cleanup functionality that can be enabled by uncommenting the cleanup call. When enabled, it will:
- Remove all previous result files (`*-results.json` and `*-results.html`)
- Remove all previous exported service bundles from `generated/` directory
- Preserve the input data file (`spFolderSVCFull.json`)

**Note**: Cleanup is currently **disabled by default** to prevent accidental deletion of files. Enable it by editing `searchAssertions.sh` if you want automatic cleanup before each run.

---

### 6. replaceServer.js

A simple HTTP server that provides an API endpoint to execute `ReplaceAssertions.js` from the HTML interface. This allows the "Replace and Import" button in the HTML reports to trigger assertion replacement.

#### Usage

```bash
node replaceServer.js
```

#### What it does

1. Starts an HTTP server on port 3001
2. Provides two API endpoints:
   - `/api/replace-and-import` - For assertion replacement (executes `ReplaceAssertions.js`)
   - `/api/import-bundles` - For bundle import (executes `ImportBundles.js`)
3. Executes the appropriate script based on the endpoint called
4. Returns success/error responses to the HTML client

#### API Endpoints

**POST** `/api/replace-and-import`

Executes `ReplaceAssertions.js` to replace assertions in bundle files.

**Request Body**:
```json
{
  "resultsFile": "response/evaluatejsonpathexpressionv2-results.json",
  "searchAssertion": "EvaluateJsonPathExpressionV2",
  "replaceAssertion": "EvaluateJsonPathExpressionV3"
}
```

**Response** (Success):
```json
{
  "success": true,
  "message": "Replace operation completed successfully",
  "output": "..."
}
```

**Response** (Error):
```json
{
  "success": false,
  "error": "Error message",
  "output": "..."
}
```

**POST** `/api/import-bundles`

Executes `ImportBundles.js` to import all bundles from `generated/` directory.

**Request Body**:
```json
{
  "graphmanHome": "../../graphman-client-main",
  "gateway": "aws"
}
```

**Response** (Success):
```json
{
  "success": true,
  "message": "Import operation completed successfully",
  "output": "..."
}
```

**Response** (Error):
```json
{
  "success": false,
  "error": "Error message",
  "output": "..."
}
```

#### Health Check

**GET** `/api/health`

Returns server status:
```json
{
  "status": "ok",
  "message": "Replace server is running"
}
```

#### Features

- **CORS enabled**: Allows requests from HTML files opened in browsers
- **Error handling**: Captures and returns script execution errors
- **Health check**: Provides endpoint to verify server is running
- **Port 3001**: Uses a separate port to avoid conflicts

#### Notes

- The server can be started automatically by `searchAssertions.sh` when you choose "Yes" to enable replacement/import
- The server must be running before using the "Replace Assertions" or "Import Bundles" buttons in HTML reports
- When started by `searchAssertions.sh`, the server runs in the background and persists after the script completes
- To stop the server manually, use: `kill <PID>` (PID is displayed when server starts)
- Or use: `pkill -f "replaceServer.js"` to stop any running instance
- The server provides two separate endpoints for replace and import operations, allowing independent use of each functionality

---

### 7. cleanup.sh

Bash script that removes previous result files and generated exports, while preserving input data.

#### Usage

```bash
./cleanup.sh
```

#### What it does

1. **Checks and stops replaceServer.js** (if running):
   - Checks if `replaceServer.js` is currently running
   - If found, stops the process gracefully
   - Reports the PID and status of the operation

2. **Cleans `generated/` directory**:
   - Removes all `.json` files (exported service and policy bundles)
   - Preserves the directory structure

3. **Cleans `response/` directory**:
   - Removes all `*-results.json` files (search result JSON files)
   - Removes all `*-results.html` files (search result HTML reports)
   - **Preserves** `spFolderSVCFull.json` (input service data file)

4. **Provides summary**: Shows how many files were removed from each directory

#### Features

- **Server management**: Automatically checks and stops `replaceServer.js` if running
- **Safe cleanup**: Only removes result files, never touches input data
- **Color-coded output**: Uses colors for better readability (green for success, yellow for info, red for errors)
- **Detailed reporting**: Shows exactly what was removed and server status
- **Standalone**: Can be run independently or integrated into other scripts

#### Output Example

```
==========================================
Cleanup Script
==========================================
Checking for running replaceServer.js...
  Found replaceServer.js running (PID: 12345)
✓ Stopped replaceServer.js (PID: 12345)

Cleaning generated/ directory...
✓ Removed 3 file(s) from generated/
Cleaning response/ directory (result files only)...
✓ Removed 2 JSON result file(s) from response/
✓ Removed 2 HTML result file(s) from response/
ℹ Preserved input file: spFolderSVCFull.json

==========================================
Cleanup Summary:
  Generated files removed: 3
  Response files removed: 4
  Total files removed: 7
==========================================
```

**Note**: If `replaceServer.js` is not running, the output will show:
```
Checking for running replaceServer.js...
  No replaceServer.js process found
```

#### Integration with searchAssertions.sh

The cleanup script can be integrated into `searchAssertions.sh` to automatically clean previous results before running a new search. Currently, this is **disabled by default** but can be enabled by uncommenting the cleanup call in `searchAssertions.sh`.

To enable automatic cleanup, edit `searchAssertions.sh` and uncomment these lines:
```bash
# Run cleanup script to remove previous results
echo "Cleaning up previous results..."
"$SCRIPT_DIR/cleanup.sh"
echo ""
```

---

## Workflow

### Typical Usage Flow

#### Option 1: Using the Bash Script (Recommended)

```bash
# Complete workflow in one command
./searchAssertions.sh EvaluateJsonPathExpressionV2 ../../graphman-client-main --gateway aws
```

This single command will:
1. Ask if you want to enable assertion replacement and import functionality (Yes/No)
   - Answer **"Yes"** to enable both "Replace Assertions" and "Import Bundles" buttons in HTML reports
   - Answer **"No"** to disable both buttons (grayed out)
2. Export service and policy data from the gateway
3. Search for the specified assertion (with replace/import buttons enabled/disabled based on your choice)
4. Export individual service and policy bundles
5. If replacement/import enabled: Start replace server for HTML-based replacement and import

#### Option 2: Manual Step-by-Step

1. **Export service data** (if not already done):
   ```bash
   ../../graphman-client-main/graphman.sh export --gateway aws --using all --output response/spFolderSVCFull.json
   ```

2. **Search for assertions**:
   ```bash
   node SearchAssertions.js EvaluateJsonPathExpressionV2
   ```

3. **Review the HTML report**:
   - Open `response/evaluatejsonpathexpressionv2-results.html` in a browser
   - Review which services and policies contain the assertion
   - Note the Serial No, Type, Name, Resolution Path, and Folder Path

4. **Export services and policies** (optional):
   ```bash
   node ExportBundles.js ../../graphman-client-main --gateway aws
   ```
   - This will export all services and policies where `exists: true` from all results files

5. **Replace assertions** (optional):
   
   **Option A: Using HTML Interface** (if enabled when running `searchAssertions.sh`)
   - The replace server should already be running (started automatically if you answered "Yes")
   - If not running, start it manually:
     ```bash
     node replaceServer.js
     ```
   - Open the HTML report in a browser (e.g., `response/evaluatejsonpathexpressionv2-results.html`)
   - Enter the replacement assertion name in the "Assertions To Replace" field
   - Click **"Replace Assertions"** button (purple button)
   - The script will update all bundle files in `generated/` directory
   
   **Option B: Using Command Line**
   ```bash
   node ReplaceAssertions.js response/evaluatejsonpathexpressionv2-results.json EvaluateJsonPathExpressionV2 EvaluateJsonPathExpressionV3
   ```
   - This will replace assertions in all bundle files based on the search results

6. **Import bundles** (optional):
   
   **Option A: Using HTML Interface** (if enabled when running `searchAssertions.sh`)
   - The replace server should already be running (started automatically if you answered "Yes")
   - Open the HTML report in a browser
   - Click **"Import Bundles"** button (green button)
   - The script will import all bundle files from `generated/` directory to the gateway
   
   **Option B: Using Command Line**
   ```bash
   node ImportBundles.js ../../graphman-client-main --gateway aws
   ```
   - This will import all bundle files from `generated/` directory to the specified gateway
   - Use this after modifying bundles with `ReplaceAssertions.js` to import updated bundles back to the gateway

7. **Access exported bundles**:
   - Click on service or policy names in the HTML report to view exported JSON files
   - Or navigate to `generated/` directory
   - Updated bundle files are ready to be imported back to the gateway

---

## Directory Structure

```
Find-Assertions/
├── SearchAssertions.js          # Main search script
├── ExportBundles.js              # Service and policy export script
├── ImportBundles.js              # Service and policy import script
├── ReplaceAssertions.js          # Assertion replacement script
├── replaceServer.js              # HTTP server for HTML replace functionality
├── searchAssertions.sh          # Bash script for complete workflow
├── cleanup.sh                   # Cleanup script for removing old results
├── README.md                    # This file
├── broadcom.png                 # Logo for HTML reports
├── response/                    # Input/Output directory
│   ├── spFolderSVCFull.json    # Input: Service data (preserved by cleanup)
│   ├── *-results.json          # Output: Search results (JSON)
│   └── *-results.html          # Output: Search results (HTML)
└── generated/                   # Output: Exported service and policy bundles
    ├── <name>.json              # Individual service or policy exports
    └── <name>.backup.*.json    # Backup files created by ReplaceAssertions.js
```

---

## Configuration

### Graphman Path

The scripts can accept GRAPHMAN_HOME as a parameter:
- **Default**: `../../graphman-client-main` (relative to script location)
- **Can be overridden**: Pass as argument to `ExportBundles.js` or `searchAssertions.sh`

### Gateway

Default gateway is set to `aws`. Can be changed using:
- **Command-line argument**: `--gateway <gateway-name>` for `ExportBundles.js`, `ImportBundles.js`, and `searchAssertions.sh`
- **Examples**: `aws`, `source`, `target`

### Input File

The scripts read service and policy data from:
```
response/spFolderSVCFull.json
```

This file is typically generated by running the graphman export command or using `searchAssertions.sh`. The file can contain:
- A `services` array (for service bundles)
- A `policies` array (for policy bundles)
- Both arrays (for combined bundles)

---

## Error Handling

### SearchAssertions.js

- **File not found**: Checks if input JSON file exists
- **Invalid JSON**: Validates JSON structure
- **Missing properties**: Handles missing policy.code structures gracefully
- **Flexible bundle support**: Works with bundles containing services only, policies only, or both
- **Type handling**: Properly distinguishes between services and policies in results

### ExportBundles.js

- **Missing resolutionPath**: Skips services without resolution paths
- **Policy export**: Policies are exported using name-based lookup with dependencies included
- **Export failures**: Provides detailed error messages with stdout/stderr
- **File verification**: Confirms exported files were created before marking as successful
- **Type handling**: Properly distinguishes between services and policies for appropriate export commands

### ImportBundles.js

- **Missing generated directory**: Validates that `generated/` directory exists before processing
- **No bundle files**: Reports when no bundle files are found (suggests running ExportBundles.js first)
- **Import failures**: Provides detailed error messages with stdout/stderr for each failed import
- **Backup exclusion**: Automatically excludes backup files (`.backup.*.json`) from import
- **Individual imports**: Each bundle is imported separately, allowing partial success if some imports fail

### ReplaceAssertions.js

- **Missing results file**: Validates that the results file exists before processing
- **Missing bundle files**: Reports which bundle files are missing (suggests running ExportBundles.js first)
- **Invalid JSON**: Handles JSON parsing errors gracefully
- **Backup creation**: Creates backups before modifying files
- **Type validation**: Verifies bundle structure before processing

### replaceServer.js

- **Port conflicts**: Detects if port 3001 is already in use
- **Connection errors**: Provides clear error messages if server can't start
- **Script execution errors**: Captures and returns errors from ReplaceAssertions.js execution

---

## Notes

- The script searches both services and policies in the Graphman bundle, providing comprehensive assertion search results
- The HTML report Replace and Import section includes a **Caution** label: the feature is intended for lower environments, with proper quality testing planned for "Replace Assertions" before importing policies/services into the Gateway
- Service and policy names in HTML reports are clickable links (for items with `exists: true`) that open the exported bundle files
- Both services and policies are exported individually to the `generated/` directory
- HTML table includes Serial No, Type, and Folder Path columns for better item identification
- File names are automatically sanitized (special characters replaced with underscores)
- The HTML report includes a professional grey theme with color-coded rows
- All outputs are saved in the `response/` directory for search results and `generated/` for exports
- Both `ExportBundles.js` and `ImportBundles.js` accept GRAPHMAN_HOME and `--gateway` parameters for flexibility
- Use `ImportBundles.js` to import all bundle files from `generated/` directory back to the gateway after modifications
- Use `cleanup.sh` to remove old result files and generated exports when needed
- Cleanup script preserves input data (`spFolderSVCFull.json`) and can be integrated into `searchAssertions.sh`
- Policies don't have resolution paths, so they show "N/A" in the Resolution Path column

---

## Troubleshooting

### SearchAssertions.js

**Issue**: No results found
- **Solution**: Verify the input JSON file contains services with policies
- Check that the assertion name matches exactly (case-sensitive for assertion type)

**Issue**: HTML logo not displaying
- **Solution**: Ensure `broadcom.png` is in the parent directory (one level up from `response/`)

### ExportBundles.js

**Issue**: No services or policies to export
- **Solution**: Run `SearchAssertions.js` first to generate results files
- Ensure services or policies have `exists: true` in the results

**Issue**: Export fails with "file not found"
- **Solution**: Verify graphman path is correct
- Check gateway connectivity and permissions
- Ensure resolutionPath is valid for the gateway

**Issue**: Exported files contain multiple services
- **Solution**: This should not happen with the current implementation. If it does, verify you're using `--using service` (not `--using folder`)

### ImportBundles.js

**Issue**: "No bundle files found" error
- **Solution**: Run `ExportBundles.js` first to generate the bundle files in `generated/` directory
- Ensure the `generated/` directory exists and contains `.json` files

**Issue**: Import fails with "file not found"
- **Solution**: Verify graphman path is correct
- Check gateway connectivity and permissions
- Ensure bundle files are valid JSON

**Issue**: Import fails for specific bundles
- **Solution**: Check the error output for each failed import
- Verify bundle files are properly formatted and contain valid service or policy data
- Ensure the gateway has the necessary permissions to import the bundle type

### ReplaceAssertions.js

**Issue**: "Bundle files not found" error
- **Solution**: Run `ExportBundles.js` first to generate the bundle files in `generated/` directory
- Ensure the bundle file names match the item names from search results

**Issue**: "No items found with the assertion to replace"
- **Solution**: Verify the search results file contains items with `exists: true`
- Check that you're using the correct results file for the assertion you searched

**Issue**: Replacement not working
- **Solution**: Verify the searchAssertion parameter matches exactly what was searched
- Check that bundle files contain the assertion (may need to re-export if source changed)

### replaceServer.js

**Issue**: "Server not found" error in HTML
- **Solution**: Start the server by running `node replaceServer.js` in a terminal
- Keep the server running while using the HTML interface
- Verify the server is accessible at `http://localhost:3001/api/health`

**Issue**: Port 3001 already in use
- **Solution**: Stop the other process using port 3001, or modify the PORT constant in `replaceServer.js`

---

## Support

For issues or questions, please check:
1. Graphman documentation
2. Layer7 API Gateway documentation
3. Verify all prerequisites are met

---

## Version History

- **v1.6**: Latest updates
  - **Split HTML buttons**: Separated "Replace and Import" into two independent buttons
    - **"Replace Assertions" button** (purple): Handles assertion replacement via `ReplaceAssertions.js`
    - **"Import Bundles" button** (green): Handles bundle import via `ImportBundles.js`
    - Both buttons can be used independently
  - **Enhanced replaceServer.js**: Added new `/api/import-bundles` endpoint
    - Supports separate import operations independent of replace
    - Both endpoints (`/api/replace-and-import` and `/api/import-bundles`) available simultaneously
  - **Improved user interaction**: Updated `searchAssertions.sh` prompt
    - Now asks: "Do you want to enable assertion replacement and import functionality? (Yes/No)"
    - Enables/disables both buttons together based on user choice
    - Clearer messaging about what gets enabled/disabled

- **v1.5**: Previous updates
  - **Added ImportBundles.js**: New script to import all bundle files from `generated/` directory
    - Imports all `.json` files from `generated/` directory to specified gateway
    - Automatically excludes backup files (`.backup.*.json`)
    - Supports both Service and Policy bundle types
    - Uses same parameter structure as `ExportBundles.js` (GRAPHMAN_HOME and `--gateway`)
    - Provides detailed import status and summary
  - **Complete import workflow**: Added import capability to complete the export → modify → import cycle
    - Export bundles with `ExportBundles.js`
    - Modify bundles with `ReplaceAssertions.js`
    - Import updated bundles with `ImportBundles.js`

- **v1.4**: Previous updates
  - **Added ReplaceAssertions.js**: New script to replace assertions in exported bundle files
    - Uses search results to identify items needing replacement (no duplicate search)
    - Updates individual bundle files in `generated/` directory
    - Creates timestamped backups before modification
    - Supports both Service and Policy bundle types
  - **Added replaceServer.js**: HTTP server for HTML-based replace functionality
    - Provides `/api/replace-and-import` endpoint
    - Health check endpoint at `/api/health`
    - Runs on port 3001
  - **Enhanced HTML reports**: Added "Replace and Import" functionality
    - Interactive form with text field for replacement assertion name
    - Button to trigger assertion replacement via server
    - Improved error messages with setup instructions
  - **Improved workflow**: Complete search → export → replace → import workflow
    - Search for assertions
    - Export bundles
    - Replace assertions in bundles (via HTML or command line)
    - Import updated bundles back to gateway

- **v1.3**: Previous updates
  - **Enhanced search capability**: SearchAssertions.js now searches both services and policies in Graphman bundles
  - **Enhanced export capability**: ExportBundles.js (renamed from ExportServices.js) now exports both services and policies
  - Services exported using `--using service --variables.resolutionPath`
  - Policies exported using `--using policy --variables.name --variables.includeAllDependencies`
  - Added Type column to HTML reports to distinguish between Services and Policies
  - Updated JSON output to include `type`, `totalPolicies`, `totalItems`, and `itemsWithAssertion` fields
  - Improved statistics display showing separate counts for services and policies
  - Support for bundles containing only services, only policies, or both
  - Policies show "N/A" for resolution path (services only have resolution paths)
  - Both service and policy names are now clickable links in HTML reports
  - Export summary shows separate counts for services and policies with overall totals
  - **File renamed**: `ExportServices.js` renamed to `ExportBundles.js` to better reflect its dual export capability

- **v1.2**: Previous updates
  - Added cleanup.sh script for removing previous results and generated files
  - Cleanup integration option in searchAssertions.sh (disabled by default)
  - Improved error handling in ExportBundles.js with better graphman output capture

- **v1.1**: Previous updates
  - Added Serial No and Folder Path columns to HTML table
  - ExportBundles.js now accepts GRAPHMAN_HOME and --gateway parameters
  - Added searchAssertions.sh bash script for complete workflow automation
  - Improved parameter handling and error messages

- **v1.0**: Initial release
  - SearchAssertions.js with HTML and JSON output
  - ExportBundles.js (originally ExportServices.js) for individual service exports
  - Support for nested policy structures (OneOrMore.All)
  - Interactive HTML reports with clickable service links
