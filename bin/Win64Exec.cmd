@echo off

:: Keep variables localized to this script.
setlocal

:: Detect Wine and bail out since it it missing a full findstr implemention.
if defined WINEUSERNAME (
    echo Cannot run under Linux Wine since command findstr is missing the /r regex option.
    exit /b 1
)

:: When exec_dir is not defined use this scripts directory.
if not defined exec_dir (
	set exec_dir=%~dp0
)

:: Initialize the variable
set "qt_ver_dir="

:: Loop through all possible locations.
for %%d in (
	%exec_dir%..\lib\QtW64
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
cd /d %exec_dir%\win64

:: Set the PATH for the found Qt library and the relative 'lib' directory.
set PATH=%PATH%;%qt_ver_dir%\mingw_64\bin;.\lib

:: Start the application in the foreground and current window.
start /WAIT /B %exec_dir%win64\%*

:: Restore the directory to as it was before.
popd

endlocal
