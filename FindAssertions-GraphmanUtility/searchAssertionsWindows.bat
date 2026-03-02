@echo off
REM Parse command-line arguments
REM Usage: searchAssertionsWindows.bat [ASSERTION_TYPE] [GRAPHMAN_HOME] [--gateway GATEWAY]
REM Example: searchAssertionsWindows.bat EvaluateJsonPathExpressionV2 ..\..\graphman-client-main --gateway aws
REM Example: searchAssertionsWindows.bat SetVariable --gateway source
REM Example: searchAssertionsWindows.bat

REM Default values
set "GRAPHMAN_HOME=..\..\graphman-client-main"
set "GATEWAY=aws"
set "ASSERTION_TYPE=EvaluateJsonPathExpressionV2"

REM Parse arguments
setlocal enabledelayedexpansion
set "POSITIONAL_COUNT=0"

:parse_args
if "%~1"=="" goto args_done
if "%~1"=="--gateway" (
    set "GATEWAY=%~2"
    shift
    shift
    goto parse_args
)
set /a POSITIONAL_COUNT+=1
if !POSITIONAL_COUNT!==1 set "ASSERTION_TYPE=%~1"
if !POSITIONAL_COUNT!==2 set "GRAPHMAN_HOME=%~1"
shift
goto parse_args

:args_done

echo ==========================================
echo Search Assertions Script
echo ==========================================
echo GRAPHMAN_HOME: %GRAPHMAN_HOME%
echo Gateway: %GATEWAY%
echo Assertion Type: %ASSERTION_TYPE%
echo ==========================================
echo.

REM Get script directory
set "SCRIPT_DIR=%~dp0"
set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"

REM Run cleanup script to remove previous results
REM Note: cleanup.sh is a bash script and requires Git Bash or WSL on Windows
REM Disabled - uncomment if you want to cleanup before running
REM If you have Git Bash installed, you can uncomment the following lines:
REM echo Cleaning up previous results...
REM bash "%SCRIPT_DIR%\cleanup.sh"
REM if errorlevel 1 (
REM     echo Warning: Cleanup script may have failed or is not available
REM )
REM echo.

REM Export service data using graphman
REM Note: If graphman.sh doesn't work on Windows, you may need to use graphman.bat or graphman.cmd
REM Or ensure you have Git Bash/WSL installed to run .sh files
echo Exporting the Service GatewayInfo...
"%GRAPHMAN_HOME%\graphman.sh" export --gateway %GATEWAY% --using all --output response\spFolderSVCFull.json

if errorlevel 1 (
    echo Error: Failed to export service data
    exit /b 1
)

echo.
echo ==========================================
echo Would you like to enable assertion replacement and import functionality?
echo ==========================================
echo This will:
echo   1. Enable the 'Replace Assertions' and 'Import Bundles' buttons in the HTML report
echo   2. Start the replace server (replaceServer.js) for interactive replacement and import
echo   3. Allow you to replace assertions and import bundles via the HTML interface
echo.
set /p REPLACE_CHOICE="Enable assertion replacement and import functionality? (Yes/No): "

REM Convert to lowercase for comparison
set "REPLACE_CHOICE=%REPLACE_CHOICE:YES=yes%"
set "REPLACE_CHOICE=%REPLACE_CHOICE:Yes=yes%"
set "REPLACE_CHOICE=%REPLACE_CHOICE:Y=y%"

if /i "%REPLACE_CHOICE%"=="yes" (
    set "REPLACE_ENABLED=true"
    echo [SUCCESS] Assertion replacement and import will be enabled
) else if /i "%REPLACE_CHOICE%"=="y" (
    set "REPLACE_ENABLED=true"
    echo [SUCCESS] Assertion replacement and import will be enabled
) else (
    set "REPLACE_ENABLED=false"
    echo [SUCCESS] Assertion replacement and import will be disabled
    REM Kill any existing replace server
    REM Try to find and kill node processes running replaceServer.js
    for /f "tokens=2" %%a in ('tasklist /FI "IMAGENAME eq node.exe" /FO CSV ^| findstr /C:"replaceServer.js"') do (
        taskkill /F /PID %%a >nul 2>&1
    )
    REM Alternative method: use wmic to find processes with replaceServer.js in command line
    for /f "tokens=2 delims=," %%a in ('wmic process where "name='node.exe' and commandline like '%%replaceServer.js%%'" get processid /format:csv ^| findstr /V "Node"') do (
        if not "%%a"=="" taskkill /F /PID %%a >nul 2>&1
    )
)

echo.
echo Searching for assertions...
REM Run SearchAssertions.js with assertion type and replace flag
node SearchAssertions.js "%ASSERTION_TYPE%" --replace-enabled "%REPLACE_ENABLED%"

if errorlevel 1 (
    echo Error: Failed to search for assertions
    exit /b 1
)

echo.
echo Exporting services and policies...
REM Run ExportBundles.js with GRAPHMAN_HOME and gateway parameters
node ExportBundles.js "%GRAPHMAN_HOME%" --gateway "%GATEWAY%"

if errorlevel 1 (
    echo Error: Failed to export services and policies
    exit /b 1
)

REM If replacement is enabled, start server for HTML interface
if "%REPLACE_ENABLED%"=="true" (
    echo.
    echo Starting replace server...
    REM Start replaceServer.js in background
    start /B "" node "%SCRIPT_DIR%\replaceServer.js" >nul 2>&1
    
    REM Wait a moment for server to start
    timeout /t 2 /nobreak >nul
    
    echo Replace server started
    echo Server running at http://localhost:3001/
    echo.
    echo [SUCCESS] Replace server is running and ready
    echo You can use the 'Replace Assertions' and 'Import Bundles' buttons in the HTML report.
    echo.
    echo To stop the server later, you can:
    echo   1. Use Task Manager to find and end the node.exe process running replaceServer.js
    echo   2. Or run: wmic process where "commandline like '%%replaceServer.js%%'" delete
)

echo.
echo ==========================================
echo Process completed successfully!
echo ==========================================

if "%REPLACE_ENABLED%"=="true" (
    echo.
    echo Note: Replace server is running in the background
    echo To stop it, use Task Manager or find the node.exe process running replaceServer.js
)

endlocal
