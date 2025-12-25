@echo off
setlocal

REM Run minesweepe.exe with console enabled for debugging
cd /d "%~dp0"
echo Running minesweepe.exe with console...
minesweepe.exe console

endlocal
