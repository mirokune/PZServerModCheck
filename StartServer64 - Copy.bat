@echo off
setlocal enableextensions enabledelayedexpansion

:: Set server directory, password, and server address
SET server_dir=D:\PZServer
SET zomboid_dir=C:\Users\<username>\Zomboid\Logs
SET password="password"
SET server=127.0.0.1:27015
SET rcon="D:\PZServer\rcon-0.10.3-win64\rcon.exe"

:: Main loop
:mainLoop
echo [Main Loop] Calling findLogFile
call :findLogFile
echo [Main Loop] Calling checkServerStatus
call :checkServerStatus
timeout /t 3600
goto mainLoop

:: Find the most recently modified log file that contains 'DebugLog-server'
:findLogFile
FOR /F "delims=" %%I IN ('DIR "%zomboid_dir%\*DebugLog-server*" /B /O-D /A:-D /T:W') DO (
    SET "logfile=%zomboid_dir%\%%I"
    ECHO [findLogFile] Using log file: !logfile!
    goto :breakLoop
)
:breakLoop
goto :eof

:: Check server status and handle accordingly
:checkServerStatus
%rcon% -a %server% -p %password% "version" > nul 2>&1
if %errorlevel% equ 0 (
    echo [checkServerStatus] Server is running.
    call :checkLogForUpdates
) else (
    echo [checkServerStatus] Server is not running. Attempting to start the server.
    call :startServer
)
goto :eof

:: Check log file for mod update messages and take appropriate action
:checkLogForUpdates
echo [checkLogForUpdates] Starting checkLogFileUpdates

%rcon% -a %server% -p %password% "checkModsNeedUpdate"
timeout /t 3
set "totalLines=0"
for /f %%a in ('type "!logfile!" ^| find /c /v ""') do set /a "totalLines=%%a"
set /a "startLine=!totalLines!-25"
if !startLine! lss 1 set "startLine=1"

:: Processing the last 25 lines
for /f "tokens=5 delims=:" %%a in ('more +!startLine! "!logfile!"') do (
    set "lineText=%%a"
	::echo Processing line !lineText!
	echo !lineText! | findstr /C:"Mods need update" > nul && (
        echo [checkLogForUpdates] Mods need update - initiating server shutdown for updates.
        call :initiateRestart
    )
    echo !lineText! | findstr /C:"Mods updated" > nul && (
        echo [checkLogForUpdates] Mods are up-to-date - no action required.
    )
)

goto :eof

:: Function to initiate restart and server shutdown
:initiateRestart
call :checkPlayers
if !playerCount! equ 0 (
    echo [initiateRestart] No active players. Server restarting immediately.
    %rcon% -a %server% -p %password% "quit"
	timeout /t 30
    call :startServer
) else (
    for /l %%i in (5,-1,1) do (
        echo [initiateRestart] !playerCount! active players found. Sending restart message for %%i minutes.
        %rcon% -a %server% -p %password% "servermsg \"server is restarting in %%i min\""
        timeout /t 60
        call :checkPlayers
        if !playerCount! equ 0 (
            echo [initiateRestart] No active players found. Server restarting now.
            %rcon% -a %server% -p %password% "quit"
			timeout /t 30
            call :startServer
        )
    )
)
goto :eof

:: Start the server
:startServer
echo [startServer] Starting Project Zomboid Server
start "Project Zomboid Server" cmd /k "%server_dir%\StartServer64.bat"
goto :eof

:: Function to check player count
:checkPlayers
%rcon% -a %server% -p %password% "players" > "%server_dir%\players.txt" 2>&1
set "playerCount=0"
for /f "tokens=2 delims=()" %%a in ('findstr /C:"Players connected" "%server_dir%\players.txt"') do (
    set "playerCount=%%a"
)
echo [checkPlayers] Current player count: !playerCount!
goto :eof

:: Clean up and prepare for next cycle
:endScript
if exist "%server_dir%\players.txt" del "%server_dir%\players.txt"
echo [endScript] Cleaned up for next cycle.
goto :eof
