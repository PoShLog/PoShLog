function Install-PoShLogExtension {
	[Cmdletbinding()]
	param(
		[Parameter(Mandatory = $true)]
		[string]$Id,
		[Parameter(Mandatory = $true)]
		[string]$Version,
		[Parameter(Mandatory = $false)]
		[string]$TargetFramework = 'net461',
		[Parameter(Mandatory = $false)]
		[switch]$Silent
	)

	[xml]$xml = Get-Content $Global:packagesConfigPath
	$packages = $xml.SelectSingleNode("//packages")
	$package = $xml.SelectSingleNode("//package[@id='$Id']")

	if ($Version -notmatch '(?<major>\d+|\*)(\.(?<minor>\d+|\*))?(\.(?<bugfix>\d+|\*))?') {
		Write-Error 'Wrong version format!'
	}
	else {
		$targetVersionMajor = $Matches.Major
		$targetVersionMinor = $Matches.Minor
		$targetVersionBugfix = $Matches.Bugfix

		if ($null -ne $package) {
			$currentVersion = $package.Attributes | Where-Object { $_.Name -eq 'version' } | Select-Object -ExpandProperty Value
			$currentVersion -match '(?<major>\d+|\*)(\.(?<minor>\d+|\*))?(\.(?<bugfix>\d+|\*))?' | Out-Null
	
			if ($Matches.Major -lt $targetVersionMajor -or 
				($Matches.Major -eq $targetVersionMajor -and $Matches.Minor -lt $targetVersionMinor) -or
				($Matches.Major -eq $targetVersionMajor -and $Matches.Minor -eq $targetVersionMinor -and $Matches.Bugfix -lt $targetVersionBugfix)
			) {
				$package.Attributes | Where-Object { $_.Name -eq 'version' } | ForEach-Object { $_.Value = $Version } 
				$changed = $true
			}
			else {
				if (-not $Silent) {
					Write-Warning "Package $Id is already installed with same or higher version."
				}
			}
		}
		else {
			$package = $xml.CreateElement("package")
	
			$idAttr = $xml.CreateAttribute("id")
			$idAttr.Value = $Id
			$package.SetAttributeNode($idAttr);
		
			$versionAttr = $xml.CreateAttribute("version")
			$versionAttr.Value = $Version
			$package.SetAttributeNode($versionAttr);
		
			$targetFrameworkAttr = $xml.CreateAttribute("targetFramework")
			$targetFrameworkAttr.Value = $TargetFramework
			$package.SetAttributeNode($targetFrameworkAttr);
		
			$packages.AppendChild($package)
			$changed = $true
		}
		
		if ($changed) {
			$xml.Save($Global:packagesConfigPath)
	
			Restore-AllExtensions -Silent:$Silent

			# Load package dlls
			$assemblies = Get-ChildItem "$Global:packagesPath\$Id.$Version\lib\*" | Where-Object { $_.Name -match 'net\d+' } | ForEach-Object { Get-ChildItem "$($_.FullName)\*.dll" }
			Add-Type -Path $assemblies -ErrorAction 'Stop'
		}
	}	
}
