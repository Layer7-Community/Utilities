#!/bin/bash

# Cleanup script for Find-Assertions directory
# Removes generated files and result files, but preserves input data

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GENERATED_DIR="$SCRIPT_DIR/generated"
RESPONSE_DIR="$SCRIPT_DIR/response"

# Counters
GENERATED_COUNT=0
RESPONSE_COUNT=0

echo "=========================================="
echo "Cleanup Script"
echo "=========================================="

# Check and kill replaceServer.js if running
echo "Checking for running replaceServer.js..."
REPLACE_SERVER_PID=$(pgrep -f "replaceServer.js" | head -n 1)
if [ -n "$REPLACE_SERVER_PID" ]; then
  echo "  Found replaceServer.js running (PID: $REPLACE_SERVER_PID)"
  kill "$REPLACE_SERVER_PID" 2>/dev/null
  if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓${NC} Stopped replaceServer.js (PID: $REPLACE_SERVER_PID)"
  else
    echo -e "${RED}✗${NC} Failed to stop replaceServer.js (PID: $REPLACE_SERVER_PID)"
  fi
else
  echo "  No replaceServer.js process found"
fi

echo ""

# Cleanup generated directory
if [ -d "$GENERATED_DIR" ]; then
  echo "Cleaning generated/ directory..."
  GENERATED_COUNT=$(find "$GENERATED_DIR" -type f -name "*.json" | wc -l | tr -d ' ')
  if [ "$GENERATED_COUNT" -gt 0 ]; then
    find "$GENERATED_DIR" -type f -name "*.json" -delete
    echo -e "${GREEN}✓${NC} Removed $GENERATED_COUNT file(s) from generated/"
  else
    echo "  No files to remove in generated/"
  fi
else
  echo "  generated/ directory does not exist (will be created when needed)"
fi

# Cleanup response directory (only result files, keep input file)
if [ -d "$RESPONSE_DIR" ]; then
  echo "Cleaning response/ directory (result files only)..."
  
  # Remove result JSON files
  RESPONSE_JSON_COUNT=$(find "$RESPONSE_DIR" -type f -name "*-results.json" | wc -l | tr -d ' ')
  if [ "$RESPONSE_JSON_COUNT" -gt 0 ]; then
    find "$RESPONSE_DIR" -type f -name "*-results.json" -delete
    echo -e "${GREEN}✓${NC} Removed $RESPONSE_JSON_COUNT JSON result file(s) from response/"
    RESPONSE_COUNT=$((RESPONSE_COUNT + RESPONSE_JSON_COUNT))
  fi
  
  # Remove result HTML files
  RESPONSE_HTML_COUNT=$(find "$RESPONSE_DIR" -type f -name "*-results.html" | wc -l | tr -d ' ')
  if [ "$RESPONSE_HTML_COUNT" -gt 0 ]; then
    find "$RESPONSE_DIR" -type f -name "*-results.html" -delete
    echo -e "${GREEN}✓${NC} Removed $RESPONSE_HTML_COUNT HTML result file(s) from response/"
    RESPONSE_COUNT=$((RESPONSE_COUNT + RESPONSE_HTML_COUNT))
  fi
  
  if [ "$RESPONSE_COUNT" -eq 0 ]; then
    echo "  No result files to remove in response/"
  fi
  
  # Preserve input file
  if [ -f "$RESPONSE_DIR/spFolderSVCFull.json" ]; then
    echo -e "${YELLOW}ℹ${NC} Preserved input file: spFolderSVCFull.json"
  fi
else
  echo "  response/ directory does not exist"
fi

echo ""
echo "=========================================="
echo "Cleanup Summary:"
echo "  Generated files removed: $GENERATED_COUNT"
echo "  Response files removed: $RESPONSE_COUNT"
echo "  Total files removed: $((GENERATED_COUNT + RESPONSE_COUNT))"
echo "=========================================="
