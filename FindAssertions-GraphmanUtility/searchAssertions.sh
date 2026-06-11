#!/bin/bash

# Parse command-line arguments
# Usage: ./searchAssertions.sh [ASSERTION_TYPE] [GRAPHMAN_HOME] [--gateway GATEWAY] [--schema SCHEMA]
# Example: ./searchAssertions.sh EvaluateJsonPathExpressionV2 ../../graphman-client-main --gateway aws --schema v11.1.3
# Example: ./searchAssertions.sh SetVariable --gateway source
# Example: ./searchAssertions.sh
# Defaults are loaded from config.json when present; CLI args override config values

# Get script directory first (needed to locate config.json)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load defaults from config.json if present; fall back to built-in defaults
if [ -f "$SCRIPT_DIR/config.json" ]; then
  _cfg_graphman=$(node -e "try{var c=require('$SCRIPT_DIR/config.json');console.log(c.graphmanHome||'')}catch(e){}" 2>/dev/null)
  _cfg_gateway=$(node -e "try{var c=require('$SCRIPT_DIR/config.json');console.log(c.sourceGateway||'')}catch(e){}" 2>/dev/null)
  _cfg_assertion=$(node -e "try{var c=require('$SCRIPT_DIR/config.json');console.log(c.assertionType||'')}catch(e){}" 2>/dev/null)
  _cfg_schema=$(node -e "try{var c=require('$SCRIPT_DIR/config.json');console.log(c.exportSchema||'')}catch(e){}" 2>/dev/null)
  GRAPHMAN_HOME="${_cfg_graphman:-../../graphman-client-main}"
  GATEWAY="${_cfg_gateway:-aws}"
  ASSERTION_TYPE="${_cfg_assertion:-EvaluateJsonPathExpressionV2}"
  EXPORT_SCHEMA="${_cfg_schema:-v11.1.3}"
else
  GRAPHMAN_HOME="../../graphman-client-main"
  GATEWAY="aws"
  ASSERTION_TYPE="EvaluateJsonPathExpressionV2"
  EXPORT_SCHEMA="v11.1.3"
fi

# Parse arguments (CLI args override config.json values)
POSITIONAL_ARGS=()

while [[ $# -gt 0 ]]; do
  case $1 in
    --gateway)
      GATEWAY="$2"
      shift 2
      ;;
    --schema)
      EXPORT_SCHEMA="$2"
      shift 2
      ;;
    *)
      POSITIONAL_ARGS+=("$1")
      shift
      ;;
  esac
done

# Set positional arguments
if [ ${#POSITIONAL_ARGS[@]} -ge 1 ]; then
  ASSERTION_TYPE="${POSITIONAL_ARGS[0]}"
fi

if [ ${#POSITIONAL_ARGS[@]} -ge 2 ]; then
  GRAPHMAN_HOME="${POSITIONAL_ARGS[1]}"
fi

# Export GRAPHMAN_HOME for graphman commands
export GRAPHMAN_HOME

echo "=========================================="
echo "Search Assertions Script"
echo "=========================================="
echo "GRAPHMAN_HOME: $GRAPHMAN_HOME"
echo "Gateway:       $GATEWAY"
echo "Assertion:     $ASSERTION_TYPE"
echo "Export Schema: $EXPORT_SCHEMA"
echo "=========================================="
echo ""

# Run cleanup script to remove previous results
# Disabled - uncomment if you want to cleanup before running
echo "Cleaning up previous results..."
"$SCRIPT_DIR/cleanup.sh"
echo ""

# Export service data using graphman
echo "Exporting the Service GatewayInfo..."
$GRAPHMAN_HOME/graphman.sh export --gateway $GATEWAY --using all --output response/spFolderSVCFull.json

if [ $? -ne 0 ]; then
  echo "Error: Failed to export service data"
  exit 1
fi

echo ""
echo "=========================================="
echo "Would you like to enable assertion replacement and import functionality?"
echo "=========================================="
echo "This will:"
echo "  1. Enable the 'Replace Assertions' and 'Import Bundles' buttons in the HTML report"
echo "  2. Start the replace server (replaceServer.js) for interactive replacement and import"
echo "  3. Allow you to replace assertions and import bundles via the HTML interface"
echo ""
read -p "Enable assertion replacement and import functionality? (Yes/No): " REPLACE_CHOICE

# Convert to lowercase for comparison
REPLACE_CHOICE=$(echo "$REPLACE_CHOICE" | tr '[:upper:]' '[:lower:]')

if [[ "$REPLACE_CHOICE" == "yes" || "$REPLACE_CHOICE" == "y" ]]; then
  REPLACE_ENABLED="true"
  echo "✓ Assertion replacement and import will be enabled"
else
  REPLACE_ENABLED="false"
  echo "✓ Assertion replacement and import will be disabled"
  # Kill any existing replace server
  pkill -f "replaceServer.js" 2>/dev/null
fi

echo ""
echo "Searching for assertions..."
# Run SearchAssertions.js with assertion type and replace flag
node SearchAssertions.js "$ASSERTION_TYPE" --replace-enabled "$REPLACE_ENABLED"

if [ $? -ne 0 ]; then
  echo "Error: Failed to search for assertions"
  exit 1
fi

echo ""
echo "Exporting services and policies..."
# Run ExportBundles.js with GRAPHMAN_HOME, gateway, and schema parameters
node ExportBundles.js "$GRAPHMAN_HOME" --gateway "$GATEWAY" --schema "$EXPORT_SCHEMA"

if [ $? -ne 0 ]; then
  echo "Error: Failed to export services and policies"
  exit 1
fi

# If replacement is enabled, start server for HTML interface
if [ "$REPLACE_ENABLED" == "true" ]; then
  echo ""
  echo "Starting replace server..."
  # Start replaceServer.js in background
  node "$SCRIPT_DIR/replaceServer.js" > /dev/null 2>&1 &
  REPLACE_SERVER_PID=$!
  echo "Replace server started (PID: $REPLACE_SERVER_PID)"
  echo "Server running at http://localhost:3001/"
  
  # Wait a moment for server to start
  sleep 2
  
  # Check if server started successfully
  if ! kill -0 $REPLACE_SERVER_PID 2>/dev/null; then
    echo "Warning: Replace server may have failed to start"
  else
    echo ""
    echo "✓ Replace server is running and ready"
    echo "You can use the 'Replace Assertions' and 'Import Bundles' buttons in the HTML report."
    echo "To stop the server, run: kill $REPLACE_SERVER_PID"
  fi
fi

echo ""
echo "=========================================="
echo "Process completed successfully!"
echo "=========================================="

if [ "$REPLACE_ENABLED" == "true" ]; then
  echo ""
  echo "Note: Replace server is running in the background (PID: $REPLACE_SERVER_PID)"
  echo "To stop it, run: kill $REPLACE_SERVER_PID"
fi
