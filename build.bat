@echo off
setlocal

REM Simple MASM Minesweeper build script
REM Please run in a VS Developer Command Prompt (ml/link/rc in PATH)

echo [1/4] Cleaning old build files...
rem Silently delete old files (ignore if not exist)
del /q minesweepe.obj minesweepe.exe minesweepe.res minesweepe.pdb minesweepe.ilk 2>nul

echo [2/4] Compile resources: minesweepe.rc
rc /r minesweepe.rc
if errorlevel 1 goto :build_error

echo [3/4] Assemble: minesweepe.asm
ml /c /coff /Zi minesweepe.asm
if errorlevel 1 goto :build_error

echo [4/4] Link: minesweepe.exe
link /SUBSYSTEM:CONSOLE /DEBUG minesweepe.obj minesweepe.res user32.lib gdi32.lib kernel32.lib msvcrt.lib winmm.lib
if errorlevel 1 goto :build_error

echo.
echo Build succeeded.


goto :eof

:build_error
echo.
echo *** Build failed, please check messages above. ***
echo.
pause
endlocal
