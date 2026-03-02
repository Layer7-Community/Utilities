#!/bin/bash

# Parse command-line arguments
# Usage: ./searchAssertions.sh [ASSERTION_TYPE] [GRAPHMAN_HOME] [--gateway GATEWAY]
# Example: ./searchAssertions.sh EvaluateJsonPathExpressionV2 ../../graphman-client-main --gateway aws
# Example: ./searchAssertions.sh SetVariable --gateway source
# Example: ./searchAssertions.sh

# Default values
GRAPHMAN_HOME="../../graphman-client-main"
GATEWAY="aws"
ASSERTION_TYPE="EvaluateJsonPathExpressionV2"

# Parse arguments
POSITIONAL_ARGS=()

while [[ $# -gt 0 ]]; do
  case $1 in
    --gateway)
      GATEWAY="$2"
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
echo "Gateway: $GATEWAY"
echo "Assertion Type: $ASSERTION_TYPE"
echo "=========================================="
echo ""

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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
echo "Would you like to enable assertion replacement?"
echo "=========================================="
echo "This will:"
echo "  1. Enable the 'Replace and Import' button in the HTML report"
echo "  2. Start the replace server (replaceServer.js) for interactive replacement"
echo "  3. Allow you to replace assertions in the exported bundle files"
echo ""
read -p "Enable assertion replacement? (Yes/No): " REPLACE_CHOICE

# Convert to lowercase for comparison
REPLACE_CHOICE=$(echo "$REPLACE_CHOICE" | tr '[:upper:]' '[:lower:]')

if [[ "$REPLACE_CHOICE" == "yes" || "$REPLACE_CHOICE" == "y" ]]; then
  REPLACE_ENABLED="true"
  echo "✓ Assertion replacement will be enabled"
else
  REPLACE_ENABLED="false"
  echo "✓ Assertion replacement will be disabled"
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
# Run ExportBundles.js with GRAPHMAN_HOME and gateway parameters
node ExportBundles.js "$GRAPHMAN_HOME" --gateway "$GATEWAY"

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
    echo "You can use the 'Replace and Import' button in the HTML report to replace assertions."
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
