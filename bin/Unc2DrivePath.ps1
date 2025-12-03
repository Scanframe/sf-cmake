#!pwsh-shebang.sh
param (
	[string]$InputPath
)
# Bailout when not passed.
if (-not $InputPath)
{
	Write-Error "ERROR: Missing required parameter 'InputPath'."
	exit 1
}
# Determine if input used forward slashes.
$usesForwardSlashes = $InputPath.Contains('/')
# Normalize InputPath for matching (PowerShell internally prefers '\').
$normalizedInputPath = $InputPath.Replace('/', '\')
# Get all network drive mappings.
$networkDrives = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=4"
# Sort drives by longest ProviderName first (important if multiple mappings overlap).
$networkDrives = $networkDrives | Sort-Object { $_.ProviderName.Length } -Descending
# Default output is original input.
$convertedPath = $InputPath
# Find a matching drive.
foreach ($drive in $networkDrives)
{
	if ( $normalizedInputPath.StartsWith($drive.ProviderName, [System.StringComparison]::InvariantCultureIgnoreCase))
	{
		# Replace UNC root with drive letter.
		$relativePath = $normalizedInputPath.Substring($drive.ProviderName.Length)
		# The lower case drive makes it also Cygwin compatible.
		$convertedPath = $drive.DeviceID.toLower() + $relativePath
		break
	}
}
# Adjust slashes back to match input style.
if ($usesForwardSlashes)
{
	$convertedPath = $convertedPath -replace '\\', '/'
}

Write-Host -NoNewline $convertedPath
