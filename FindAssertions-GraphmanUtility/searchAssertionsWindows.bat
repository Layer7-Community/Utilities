@echo off
REM Parse command-line arguments
REM Usage: searchAssertionsWindows.bat [ASSERTION_TYPE] [GRAPHMAN_HOME] [--gateway GATEWAY] [--schema SCHEMA]
REM Example: searchAssertionsWindows.bat EvaluateJsonPathExpressionV2 ..\..\graphman-client-main --gateway aws --schema v11.1.3
REM Example: searchAssertionsWindows.bat SetVariable --gateway source
REM Example: searchAssertionsWindows.bat
REM Defaults are loaded from config.json when present; CLI args override config values

REM Get script directory first (needed to locate config.json)
set "SCRIPT_DIR=%~dp0"
if "%SCRIPT_DIR:~-1%"=="\" set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"

REM Set built-in defaults
set "GRAPHMAN_HOME=..\..\graphman-client-main"
set "GATEWAY=aws"
set "ASSERTION_TYPE=EvaluateJsonPathExpressionV2"
set "EXPORT_SCHEMA=v11.1.3"

REM Load defaults from config.json if present (node writes a temp bat, then we call it)
if exist "%SCRIPT_DIR%\config.json" (
    node -e "try{var c=require(process.argv[2]);var o='';if(c.graphmanHome)o+='set \"GRAPHMAN_HOME='+c.graphmanHome+'\"\n';if(c.sourceGateway)o+='set \"GATEWAY='+c.sourceGateway+'\"\n';if(c.assertionType)o+='set \"ASSERTION_TYPE='+c.assertionType+'\"\n';if(c.exportSchema)o+='set \"EXPORT_SCHEMA='+c.exportSchema+'\"\n';require('fs').writeFileSync(process.argv[3],o)}catch(e){}" "" "%SCRIPT_DIR%\config.json" "%TEMP%\fa_cfg.bat" 2>nul
    if exist "%TEMP%\fa_cfg.bat" (
        call "%TEMP%\fa_cfg.bat"
        del "%TEMP%\fa_cfg.bat" >nul 2>nul
    )
)

REM Parse arguments (CLI args override config.json values)
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
if "%~1"=="--schema" (
    set "EXPORT_SCHEMA=%~2"
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
echo GRAPHMAN_HOME:  %GRAPHMAN_HOME%
echo Gateway:        %GATEWAY%
echo Assertion:      %ASSERTION_TYPE%
echo Export Schema:  %EXPORT_SCHEMA%
echo ==========================================
echo.

REM Run cleanup script to remove previous results
if exist "%SCRIPT_DIR%\cleanup.bat" (
    echo Cleaning up previous results...
    call "%SCRIPT_DIR%\cleanup.bat"
    if errorlevel 1 (
        echo Warning: Cleanup script may have failed
    )
    echo.
)

REM Export service data using graphman
echo Exporting the Service GatewayInfo...
"%GRAPHMAN_HOME%\graphman.bat" export --gateway %GATEWAY% --using all --output response\spFolderSVCFull.json

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
REM Run ExportBundles.js with GRAPHMAN_HOME, gateway, and schema parameters
node ExportBundles.js "%GRAPHMAN_HOME%" --gateway "%GATEWAY%" --schema "%EXPORT_SCHEMA%"

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
