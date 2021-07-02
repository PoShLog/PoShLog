function Test-PsCore {
	if ( -not (Get-Variable 'variable:IsWindows' -ErrorAction SilentlyContinue) ) {
		# We know we're on Windows PowerShell 5.1 or earlier
		$IsWindows = $true
		$IsLinux = $IsMacOS = $false
	}

	$PSVersionTable.PSVersion.Major -gt 5
}