@echo off
REM Copy Heaps Demo dependencies to bin\heaps
REM Run from test\ directory:  copy_heaps.bat
REM Or run from dev\ directory: test\copy_heaps.bat

echo Copying Heaps Demo dependencies...

if not exist "bin\heaps" mkdir "bin\heaps"

REM Native libraries (HashLink extension + Live2D Core + HL runtime)
copy /Y "..\lib\win\Release\live2d_hl.hdll" "bin\heaps\" >nul
copy /Y "..\lib\win\Release\live2d_capi.dll" "bin\heaps\" >nul
copy /Y "..\lib\win\Live2DCubismCore.dll" "bin\heaps\" >nul
copy /Y "..\lib\win\libhl.dll" "bin\heaps\" >nul

REM Heaps SDL driver (from HashLink install)
copy /Y "D:\haxe\hashlink\sdl.hdll" "bin\heaps\" >nul
copy /Y "D:\haxe\hashlink\openal.hdll" "bin\heaps\" >nul

REM Assets (live2d models)
if not exist "bin\heaps\assets" mkdir "bin\heaps\assets"
xcopy /Y /E /I "assets\live2d" "bin\heaps\assets\live2d\" >nul

echo.
echo Done. Run with: cd bin\heaps ^&^& hl heaps_demo.hl
echo (Ensure hl.exe is in PATH)

exit