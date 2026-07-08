@echo off
REM Copy HL (Lime/OpenFL) Demo dependencies to bin\hl\bin
REM Run from test\ directory:  copy_hl.bat
REM Or run from dev\ directory: test\copy_hl.bat

echo Copying HL Demo dependencies...

if not exist "bin\hl\bin" mkdir "bin\hl\bin"

REM Native libraries (HashLink extension + Live2D Core)
copy /Y "..\lib\win\Release\live2d_hl.hdll" "bin\hl\bin\" >nul
copy /Y "..\lib\win\Release\live2d_capi.dll" "bin\hl\bin\" >nul
copy /Y "..\lib\win\Live2DCubismCore.dll" "bin\hl\bin\" >nul

REM libhl.dll is auto-copied by Lime; do NOT manually copy to avoid version mismatch

echo.
echo Done.

exit