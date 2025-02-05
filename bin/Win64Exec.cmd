@echo off

:: Keep variables localized to this script.
setlocal

:: Detect Wine and bail out since it it missing a full findstr implementation.
if defined WINEUSERNAME (
    echo Cannot run under Linux Wine since command findstr is missing the /r regex option.
    exit /b 1
)

:: When EXECUTABLE_DIR is not defined use this scripts directory.
if not defined EXECUTABLE_DIR (
	set EXECUTABLE_DIR=%~dp0\win64\
)

:: Initialize the variable.
set "qt_ver_dir="

:: Loop through all possible locations.
for %%d in (
	%EXECUTABLE_DIR%\..\..\lib\qt\w64-x86_64
	C:\Qt D:\Qt E:\Qt F:\Qt G:\Qt H:\Qt I:\Qt J:\Qt K:\Qt L:\Qt M:\Qt N:\Qt
	O:\Qt P:\Qt Q:\Qt R:\Qt S:\Qt T:\Qt U:\Qt V:\Qt W:\Qt X:\Qt Y:\Qt Z:\Qt
	) do (
	:: Check if the Directory exists
	if exist %%d (
		REM Seems REM is needed here since '::' FU the script in Win 11. Microsoft ^%$#^%#$$#@!!!!
		REM :: Search for the directory in the current selected drive.
		REM :: There is no version sort in Windows.
		for /f "delims=" %%f in ('dir /b /ad /on %%d\*') do (
			:: Use a regular expression to match the pattern x.x.x
			echo %%f | findstr /r "^[0-9]*\.[0-9]*\.[0-9]*.$" >nul
			:: Check if the there was a match.
			if not errorlevel 1 (
				:: Assemble the path to the Qt version.
				set "qt_ver_dir=%%d\%%f"
				:: Break the loop for search drives.
				break
			)
		)
	)
)

:: Output the result
if not defined qt_ver_dir (
    echo No Qt version directory found on any of the given locations.
	exit /b 1
)

:: If the script has no argument so bailing out.
if "%~1"=="" (
    echo Error: Missing arguments.
    exit /b 1
)

:: Save the current drive and directory.
pushd

:: Change the drive and path Move to the correct start directory for relative path '.lib' entry to have effect.
cd /d %EXECUTABLE_DIR%

:: Set the PATH for the found Qt library and the relative 'lib' directory.
set PATH=%PATH%;%qt_ver_dir%\mingw_64\bin;.\lib

:: Start the application in the foreground and current window passing arguments 
:: through environment variable to the test application when running ctest.
start /WAIT /B %EXECUTABLE_DIR%\%* %CTEST_ARGS%

echo Exitcode: %ERRORLEVEL%

:: Restore the directory to as it was before.
popd

endlocal
