function Get-ErrorMessage
{
	<#
	.SYNOPSIS
		Resolves Windows Error codes (Hex, HRESULT, NTSTATUS) to text.
	.EXAMPLE
		Get-ErrorHex 0xc0000135
	#>
	param (
		[Parameter(Mandatory = $true, ValueFromPipeline = $true)]
		[string]$Code
	)
	process {
		# certutil is a built-in Windows tool that is great at decoding errors
		$certOutput = certutil -error $Code 2>&1
		# Parse the output to find the friendly message
		# We look for the line AFTER "Error message text:"
		return $certOutput;
	}
}

function Get-ExitCodeMessage
{
	[CmdletBinding()]
	param (
		[int]$code = $LASTEXITCODE
	)
	process {
		if ($code -eq 0)
		{
			return "Success (0)"
		}
		try
		{
			$msg = ([System.ComponentModel.Win32Exception]$code).Message
			return "($code) $msg"
		}
		catch
		{
			return Get-ErrorHex($Code)
		}
	}
}

function Set-ErrorMode {
	<#
  .SYNOPSIS
      Wraps the kernel32 SetErrorMode API.
  .DESCRIPTION
      Controls whether the system or the process handles the specified serious error types.
  .PARAMETER Mode
     The mode flags (uint32). Common values:
     0x0001 (SEM_FAILCRITICALERRORS)
     0x0002 (SEM_NOGPFAULTERRORBOX)
     0x8000 (SEM_NOOPENFILEERRORBOX)
  .OUTPUTS
     UInt32. Returns the previous state of the error mode bits.
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[uint32]$Mode
	)
	process {
		# Only execute when running from a bash shell.
		if ($env:SHELL -like "*bash*")
		{
			# Only add the type if it doesn't already exist
			if (-not ([System.Management.Automation.PSTypeName]'Win32.K32').Type)
			{
				Add-Type @"
using System;
using System.Runtime.InteropServices;
namespace Win32
{
  public class K32
  {
    [DllImport("kernel32.dll")]
    public static extern uint SetErrorMode(uint uMode);
  }
}
"@
			}
			return [Win32.K32]::SetErrorMode($Mode)
		}
		else
		{
			return $Mode;
		}
	}
}

function Select-Executable
{
	[CmdletBinding()]
	param(
		[Parameter(Mandatory = $false)]
		[string]$Path = $( Get-Location )
	)
	# Get the list of EXE files in the specified directory, sorted by name
	$exeFiles = Get-ChildItem -Path $Path -Filter "*.exe" -File | Sort-Object Name
	if (-not $exeFiles)
	{
		Write-Warning "No .exe files found in the path: $Path"
		return $null
	}
	# Display the menu
	Write-Host "Select an executable (CLI):"
	Write-Host "0: None"
	for ($i = 0; $i -lt $exeFiles.Count; $i++)
	{
		Write-Host "$( $i + 1 ): $( $exeFiles[$i].Name )"
	}
	# Prompt user for input within a loop
	do
	{
		Write-Host "Enter the number (1-$( $exeFiles.Count )) or '0' to quit" -ForegroundColor Green
		$selection = Read-Host
		if ($selection -match '^[0-9]+$')
		{
			$index = [int]$selection - 1
			if ($index -ge 0 -and $index -lt $exeFiles.Count)
			{
				# Valid selection made
				$selectedFile = $exeFiles[$index]
				# Return the selected FileInfo object
				return $selectedFile
			}
			else
			{
				Write-Host "Invalid number. Please try again." -ForegroundColor Red
			}
		}
		elseif ($selection -eq '0')
		{
			Write-Host "Exiting selection process."
			# Return nothing/null if the user quits.
			return $null
		}
		else
		{
			Write-Host "Invalid input. Please enter a number or '0'." -ForegroundColor Red
		}
	} until ($false)
}

function Find-QtLibDir
{
	[CmdletBinding()]
	param(
		[Parameter(Mandatory = $false)]
		[string]$Path = $( Get-Location )
	)
	$retVal = $null
	$searchRoots = @(
		Join-Path $execDir "..\..\lib\qt\win-x86_64"
		"C:\Qt", "D:\Qt", "E:\Qt", "F:\Qt", "G:\Qt", "H:\Qt", "I:\Qt", "J:\Qt", "K:\Qt",
		"L:\Qt", "M:\Qt", "N:\Qt", "O:\Qt", "P:\Qt", "Q:\Qt", "R:\Qt", "S:\Qt", "T:\Qt",
		"U:\Qt", "V:\Qt", "W:\Qt", "X:\Qt", "Y:\Qt", "Z:\Qt"
	)
	foreach ($root in $searchRoots)
	{
		if (-not (Test-Path $root))
		{
			continue
		}
		# Get the directories, sort them, and loop through the results
		foreach ($dir in Get-ChildItem -Path $root -Directory |
				Where-Object { $_.Name -match '^\d+\.\d+\.\d+$' } |
				Sort-Object { [version]$_.Name } -Descending)
		{
			Write-Host "Qt Version Dir: $( $dir.FullName )"
			$retVal = $dir.FullName
			break;
		}
		if ($retVal)
		{
			break
		}
	}
	# Bailout when no Qt versin directory was found.
	if (-not $retVal)
	{
		Write-Host "No Qt version directory found on any of the given locations."
		exit 1
	}
	return $retVal;
}
