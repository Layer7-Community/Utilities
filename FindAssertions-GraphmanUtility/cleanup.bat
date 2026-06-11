@echo off
REM Cleanup script for Find-Assertions directory
REM Removes generated files and result files, but preserves input data

setlocal enabledelayedexpansion

REM Get script directory
set "SCRIPT_DIR=%~dp0"
if "%SCRIPT_DIR:~-1%"=="\" set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"

set "GENERATED_DIR=%SCRIPT_DIR%\generated"
set "RESPONSE_DIR=%SCRIPT_DIR%\response"

REM Counters
set /a GENERATED_COUNT=0
set /a RESPONSE_COUNT=0

echo ==========================================
echo Cleanup Script
echo ==========================================

REM Check and kill replaceServer.js if running
echo Checking for running replaceServer.js...
set "REPLACE_SERVER_PID="

REM Search for node.exe processes running replaceServer.js via wmic
for /f "tokens=2 delims=," %%a in ('wmic process where "name='node.exe' and commandline like '%%replaceServer.js%%'" get processid /format:csv 2^>nul ^| findstr /V "Node,ProcessId"') do (
    set "REPLACE_SERVER_PID=%%a"
    set "REPLACE_SERVER_PID=!REPLACE_SERVER_PID: =!"
)

if defined REPLACE_SERVER_PID (
    if not "!REPLACE_SERVER_PID!"=="" (
        echo   Found replaceServer.js running ^(PID: !REPLACE_SERVER_PID!^)
        taskkill /F /PID !REPLACE_SERVER_PID! >nul 2>&1
        if !errorlevel!==0 (
            echo [SUCCESS] Stopped replaceServer.js ^(PID: !REPLACE_SERVER_PID!^)
        ) else (
            echo [FAILED]  Could not stop replaceServer.js ^(PID: !REPLACE_SERVER_PID!^)
        )
    ) else (
        echo   No replaceServer.js process found
    )
) else (
    echo   No replaceServer.js process found
)

echo.

REM Cleanup generated directory
if exist "%GENERATED_DIR%\" (
    echo Cleaning generated\ directory...
    set /a GENERATED_COUNT=0
    for %%f in ("%GENERATED_DIR%\*.json") do set /a GENERATED_COUNT+=1
    if !GENERATED_COUNT! gtr 0 (
        del /Q "%GENERATED_DIR%\*.json" >nul 2>&1
        echo [SUCCESS] Removed !GENERATED_COUNT! file^(s^) from generated\
    ) else (
        echo   No files to remove in generated\
    )
) else (
    echo   generated\ directory does not exist ^(will be created when needed^)
)

REM Cleanup response directory (only result files, keep input file)
if exist "%RESPONSE_DIR%\" (
    echo Cleaning response\ directory ^(result files only^)...

    REM Remove result JSON files
    set /a RESPONSE_JSON_COUNT=0
    for %%f in ("%RESPONSE_DIR%\*-results.json") do set /a RESPONSE_JSON_COUNT+=1
    if !RESPONSE_JSON_COUNT! gtr 0 (
        del /Q "%RESPONSE_DIR%\*-results.json" >nul 2>&1
        echo [SUCCESS] Removed !RESPONSE_JSON_COUNT! JSON result file^(s^) from response\
        set /a RESPONSE_COUNT+=!RESPONSE_JSON_COUNT!
    )

    REM Remove result HTML files
    set /a RESPONSE_HTML_COUNT=0
    for %%f in ("%RESPONSE_DIR%\*-results.html") do set /a RESPONSE_HTML_COUNT+=1
    if !RESPONSE_HTML_COUNT! gtr 0 (
        del /Q "%RESPONSE_DIR%\*-results.html" >nul 2>&1
        echo [SUCCESS] Removed !RESPONSE_HTML_COUNT! HTML result file^(s^) from response\
        set /a RESPONSE_COUNT+=!RESPONSE_HTML_COUNT!
    )

    if !RESPONSE_COUNT!==0 (
        echo   No result files to remove in response\
    )

    REM Preserve input file
    if exist "%RESPONSE_DIR%\spFolderSVCFull.json" (
        echo [INFO]    Preserved input file: spFolderSVCFull.json
    )
) else (
    echo   response\ directory does not exist
)

echo.
echo ==========================================
echo Cleanup Summary:
set /a TOTAL_COUNT=GENERATED_COUNT+RESPONSE_COUNT
echo   Generated files removed: %GENERATED_COUNT%
echo   Response files removed:  %RESPONSE_COUNT%
echo   Total files removed:     %TOTAL_COUNT%
echo ==========================================

endlocal
