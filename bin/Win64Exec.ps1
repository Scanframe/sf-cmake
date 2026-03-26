param(
	[Parameter(ValueFromRemainingArguments = $true)]
	[string[]]$ArgsFromCmd = @()
)

# Keep variables local.
Set-StrictMode -Version Latest

# Import common functions.
. "$PSScriptRoot\inc\Miscellaneous.ps1"

# Determine EXECUTABLE_DIR when not defined.
if (-not $env:EXECUTABLE_DIR -or $env:EXECUTABLE_DIR -eq "")
{
	# $PSScriptRoot = batch's %~dp0
	$env:EXECUTABLE_DIR = Join-Path $PSScriptRoot "win64"
}

# Normalize the executable path.
$execDir = (Resolve-Path $env:EXECUTABLE_DIR).Path

# Select a executable from the executable directory when the executable is not given.
if ($ArgsFromCmd.Count -eq 0)
{
	$exe = Select-Executable $execDir
}
else
{
	Write-Host $ArgsFromCmd[0] -BackgroundColor Green
	$exe = $(Get-Item "$execDir\$( $ArgsFromCmd[0] )")
}

# Search for Qt version directory.
$qtVerDir = Find-QtLibDir
# Save location and change to 'EXECUTABLE_DIR'.
Push-Location $execDir
# Prepend the environment variable 'PATH'.
$env:Path = "$( Join-Path $qtVerDir "mingw_64\bin" );lib;$( $env:Path )"

# Initialize the variable to an empty string by default.
$remainingArgs = ""
# Check if there is more than one argument
if ($ArgsFromCmd.Count -gt 1)
{
	# Add the arguments when the executable was given on the command line.
	$remainingArgs = $ArgsFromCmd[1..($ArgsFromCmd.Count - 1)] -join " "
}

# Combine arguments with optional 'CTEST_ARGS'.
$fullArgs = @()
if ($remainingArgs)
{
	$fullArgs += $remainingArgs
}
if ($env:CTEST_ARGS)
{
	$fullArgs += $env:CTEST_ARGS
}

# Set the error mode to allow dialog boxes.
$errModeSaved = Set-ErrorMode(0)

# Show what is executed.
Write-Host "Exe: $( $exe.FullName ) $fullArgs"

# Run the command in the foreground and blocking.
& $exe.FullName $fullArgs
$exitCode = $LASTEXITCODE
#Get-ExitCodeMessage($exitCode)
Get-ErrorMessage($exitCode)

# Restore the mode.
Set-ErrorMode($errModeSaved)

# Report the exit code.
#Write-Host "Exitcode: $exitCode"

# Restore directory.
Pop-Location

exit $exitCode
