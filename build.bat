@echo off
rem Build build\playsound.exe (x64) with the Microsoft C compiler (MSVC).
rem
rem Usage: build.bat
rem
rem This script finds Visual Studio with vswhere.exe and sets up the build
rem environment with VsDevCmd.bat. You can run it from a normal Command
rem Prompt or PowerShell window (also over SSH).

setlocal

rem vswhere.exe is always in this folder. Add it to PATH so that the
rem for /f command below needs no quotes ("Program Files (x86)" has
rem parentheses, which break a quoted command in for /f).
set "PATH=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer;%PATH%"
where /q vswhere.exe
if errorlevel 1 (
    echo error: vswhere.exe not found. Install Visual Studio or Build Tools for Visual Studio. 1>&2
    exit /b 1
)

set "VSDIR="
for /f "usebackq delims=" %%i in (`vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath`) do set "VSDIR=%%i"
if not defined VSDIR (
    echo error: No Visual Studio with the C++ x64 build tools was found. 1>&2
    exit /b 1
)
echo Visual Studio: %VSDIR%

call "%VSDIR%\Common7\Tools\VsDevCmd.bat" -arch=amd64 -host_arch=amd64 -no_logo
where /q cl.exe
if errorlevel 1 (
    echo error: cl.exe not found. VsDevCmd.bat did not set up the x64 build tools. 1>&2
    exit /b 1
)

set "OUT=%~dp0build"
if not exist "%OUT%" mkdir "%OUT%"

rem Compiler options:
rem   -O1    Optimize for size.
rem   -GS-   No buffer security checks. They need the C runtime.
rem   -W4    Warning level 4.
rem Linker options:
rem   -nodefaultlib       Do not link the C runtime.
rem   -entry:entry        Start the program at entry() in playsound.c.
rem   -subsystem:console  Make a console program.
rem   -manifest:no        Do not make a playsound.exe.manifest file.
cl -nologo -O1 -GS- -W4 -Fo"%OUT%\playsound.obj" -Fe"%OUT%\playsound.exe" "%~dp0playsound.c" -link -nodefaultlib -entry:entry -subsystem:console -manifest:no kernel32.lib winmm.lib
if errorlevel 1 exit /b 1

echo.
for %%f in ("%OUT%\playsound.exe") do echo %%~ff: %%~zf bytes
dumpbin -nologo -dependents "%OUT%\playsound.exe"
exit /b 0
